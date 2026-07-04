// Copyright 2026 Joseph Baldwin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of
// the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
// OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
#if !os(macOS)
import HealthKitUI
#endif
import Observation
import SwiftUI
import SwiftData
import WidgetKit

/// HealthData is a "god object" which acts as the main data store for the application. There should only ever be one instance of HealthData, which is instantiated at app start as "dataStore". You should never call HealthData(), subclass it or create a new object from it.
final class HealthData {
    static let shared = HealthData()
    
    let calorieMealConfig = ModelConfiguration(schema: Schema([CalorieEntry.self,Meal.self]), groupContainer: .identifier("group.JoeBaldwin.Budgie"), cloudKitDatabase: .private("iCloud.com.JoeBaldwin.Budgie.data"))
    let waterConfig = ModelConfiguration("waterDB", schema: Schema([WaterEntry.self]), groupContainer: .identifier("group.JoeBaldwin.Budgie"), cloudKitDatabase: .private("iCloud.com.JoeBaldwin.Budgie.data"))
    let modelContainer: ModelContainer
    let calorieActor: CalorieActor
    let waterActor: WaterActor
    private(set) var storeFailedToLoad = false
    
    private init() {
        let realContainer = try? ModelContainer(for: CalorieEntry.self, Meal.self, WaterEntry.self, configurations: calorieMealConfig, waterConfig)

        if let realContainer {
            modelContainer = realContainer
        } else {
            storeFailedToLoad = true
            // In-memory fallback: keeps the app running rather than crashing on launch.
            // Data won't persist for this session, but the user gets a working app instead of a crash.
            let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: CalorieEntry.self, Meal.self, WaterEntry.self, configurations: fallbackConfig)
        }
        calorieActor = CalorieActor(modelContainer: modelContainer)
        waterActor = WaterActor(modelContainer: modelContainer)
    }
    
    #if !os(macOS)
    ///Grabs the calorie total for a given date and type from HealthKit and (for eaten) Budgie Diet. Will pull the total of entries from the start of the date passed to the start of the following day. Set hkOnly to true if you only care about HealthKit calories.
    func pullCalorieTotalForDate(date: Date, type: HKQuantityType, hkOnly: Bool) async -> Int {
        var calories: Double = 0
        let startDate = getStartOfDay(date: date)
        let endDate = getMidnightOnDayAfter(date: startDate)

        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
        var subpredicates: [NSPredicate] = [notBudgiePredicate, timePredicate]

        if type == eatenQuantityType {
            // Exclude our mirrored samples by UUID as well as by source. HKSource.default()
            // means "this process", so on the watch or in the widget the iPhone app's samples
            // would otherwise be counted on top of the CloudKit-synced Budgie entries.
            let budgieResults = await calorieActor.fetchCalsBetween(from: startDate, to: endDate)
            let mirrored = Set(budgieResults.compactMap(\.healthKitUUID))
            if !mirrored.isEmpty {
                subpredicates.append(NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(with: mirrored)))
            }
            if hkOnly == false {
                calories = Double(budgieResults.reduce(0) { $0 + $1.calories })
            }
        }

        let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        let calsToday = HKSamplePredicate.quantitySample(type: type, predicate: queryPredicate)
        let sumActCalsQuery = HKStatisticsQueryDescriptor(predicate: calsToday, options: .cumulativeSum)
        let kcals = (try? await sumActCalsQuery.result(for: healthStore))??.sumQuantity()
        calories += kcals?.doubleValue(for: .kilocalorie()) ?? 0

        return Int(calories.rounded())
    }
    
    /// Obtain the calories eaten from both Budgie Diet's internal storage and HealthKit. Returns a tuple of Ints that include HealthKit calories plus internal Budgie calories only.
    func pullEatenCalories(startDate: Date, endDate: Date) async -> (hk: Int, budgie: Int) {
            // Budgie entries first — their mirrored HealthKit UUIDs are excluded from the HK
            // query so entries logged on another device (or the watch) are never counted twice.
            let budgieResults = await calorieActor.fetchCalsBetween(from: startDate, to: endDate)
            let budgieCalories = budgieResults.reduce(0) { $0 + $1.calories }
            let mirrored = Set(budgieResults.compactMap(\.healthKitUUID))

            var healthKitcalories: Double = 0
            let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
            var subpredicates: [NSPredicate] = [notBudgiePredicate, timePredicate]
            if !mirrored.isEmpty {
                subpredicates.append(NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(with: mirrored)))
            }
            let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
            let descriptor = HKSampleQueryDescriptor(predicates:[.quantitySample(type: eatenQuantityType, predicate: queryPredicate)], sortDescriptors: [])
            do {
                let results = try await descriptor.result(for: healthStore)
                for result in results {
                    healthKitcalories += result.quantity.doubleValue(for: HKUnit.kilocalorie())
                }
            } catch {
                healthKitcalories = 0
            }

            return (hk: Int(healthKitcalories), budgie: budgieCalories)
    }
    
    func getProjBasalCalories() async -> Int {
        let endDate = getStartOfDay(date: Date())
        let startDate = getWeekBeforeDate(date: endDate)
        let avgBasalCals = await self.getAverageCalories(from: startDate, to: endDate, type: basalQuantityType).val
        
        let calsPerMinute: Double = Double(avgBasalCals) / 1440
        let projectedCals = Double(1440 - minutesIntoDay()) * calsPerMinute
        return Int(projectedCals)
    }
    
    func getAverageWeight(from: Date, to: Date) async -> Double {
        let everyDay = DateComponents(day:1)
        
        let timePredicate = HKQuery.predicateForSamples(withStart: from, end: to, options: HKQueryOptions.strictEndDate)
        
        return await withCheckedContinuation { continuation in
            let statQuery = HKStatisticsCollectionQuery(quantityType: weightSampleType, quantitySamplePredicate: timePredicate, options: .discreteAverage, anchorDate: from, intervalComponents: everyDay)
            
            statQuery.initialResultsHandler = { query, results, error in
                guard let actCollection = results else {
                    continuation.resume(returning: 0)
                    return
                }
                
                var daysInSample: Double = 0
                var totalWeight: Double = 0
                
                actCollection.enumerateStatistics(from: from, to: to) { statistics, _ in
                    if let quantity = statistics.averageQuantity() {
                        totalWeight = totalWeight + quantity.doubleValue(for: .gram())
                        daysInSample = daysInSample + 1
                    }
                }

                // No samples in the window: report 0 ("no data") rather than dividing 0/0 into NaN.
                guard daysInSample > 0 else {
                    continuation.resume(returning: 0)
                    return
                }

                let average: Double = (totalWeight/daysInSample)/1000

                continuation.resume(returning: roundDoubleWeight(input: average))
            }
            
            healthStore.execute(statQuery)
        }
    }
    
    func getAverageCalories(from: Date, to: Date, type: HKQuantityType) async -> (val: Int, estimate: Bool, realAverage: Int) {
        let everyDay = DateComponents(day:1)
        
        let timePredicate = HKQuery.predicateForSamples(withStart: from, end: to, options: HKQueryOptions.strictEndDate)
        return await withCheckedContinuation { continuation in
            
            let statQuery = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: timePredicate, options: .cumulativeSum, anchorDate: from, intervalComponents: everyDay)
            
            statQuery.initialResultsHandler = { query, results, error in
                guard let actCollection = results else {
                    continuation.resume(returning:(val: 0, estimate: true, realAverage: 0))
                    return
                }
                
                var daysInSample: Int = 0
                var totalCals: Int = 0
                var estimated = false
                
                actCollection.enumerateStatistics(from: from, to: to) { statistics, _ in
                    if let quantity = statistics.sumQuantity() {
                        totalCals = totalCals + Int(quantity.doubleValue(for: .kilocalorie()))
                        daysInSample = daysInSample + 1
                    }
                }
                
                // Average across ONLY the days that actually had HealthKit data, with no manual
                // figure blended in. 0 means "no real data at all" (or a genuine zero-burn week).
                let realAverage = daysInSample > 0 ? totalCals / daysInSample : 0
                
                let totalDays = max(Calendar.current.dateComponents([.day], from: from, to: to).day ?? 7, 1)
                
                if daysInSample < totalDays {
                    let diff = totalDays - daysInSample
                    var toAdd: Int = 0
                    
                    if type == .quantityType(forIdentifier: .activeEnergyBurned) {
                        toAdd = settingsObj.manualActive
                    } else if type == .quantityType(forIdentifier: .basalEnergyBurned) {
                        toAdd = settingsObj.manualBMR
                    }
                    
                    totalCals = totalCals + (diff * toAdd)
                    estimated = true
                }
                
                let average = totalCals/totalDays
                
                continuation.resume(returning: (val: average, estimate: estimated, realAverage: realAverage))
            }
            
            healthStore.execute(statQuery)
        }
    }
    
    func getProjActiveCalories() async -> (value: Int, wasEstimate: Bool) {
        var averageBurn: Int = 0
        var wasEstimate: Bool = false
        var remainingFromAvg: Int = 0
        var actQuot: Double = 1
        let today: Date = Date()
        let endDate = getStartOfDay(date: today)
        let curActive = await pullCalorieTotalForDate(date: today, type: activeQuantityType, hkOnly: true)
        
        if settingsObj.useFitnessGoal != true {
            // Default behaviour - base projections on the arithmetic mean of the user's past week's active calories
            // Pull the arithmetic mean from HealthKit
            let result = await self.getAverageCalories(from: getWeekBeforeDate(date: endDate), to: endDate, type: activeQuantityType)
            
            // Only fall back to the manual figure when the past week has NO real active data at
            // all (realAverage == 0). If even one day was recorded, project off the real average
            // of the days that actually had data — never a manual blend, even if some days are
            // missing. This lets a user who's just woken up (zero active *today*) still get a
            // real-history projection while legitimately showing zero burned so far.
            if result.realAverage > 0 {
                averageBurn = result.realAverage
            } else {
                averageBurn = settingsObj.manualActive
                wasEstimate = true
            }
        } else {
            // User wants to use their Move goal as the basis for their projections. Yank it from HealthKit.
            let summary = await getActivitySummary()
            // A user with no Move goal set still gets a non-nil activeEnergyBurnedGoal back, but carrying a
            // dimensionless count unit rather than an energy one. Converting that to kilocalories throws an
            // uncatchable "incompatible units" exception, so guard it and fall back to the manual figure.
            if summary.activeEnergyBurnedGoal.is(compatibleWith: .kilocalorie()) {
                averageBurn = Int(summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()))
            } else {
                averageBurn = settingsObj.manualActive
                wasEstimate = true
            }
        }
        // Remaining from average = how much more would user have to burn to reach their previous week's average?
        remainingFromAvg = averageBurn - curActive
        
        if remainingFromAvg < 0 {
            return (value: 0, wasEstimate: wasEstimate)
        } else {
            if wasEstimate == false {
                // Work out the user's Activity Quotient. This is the percentage of the user's averageBurn that is done, plus the percentage of the day that is left. This works this way to ensure that if the user does more exercise earlier in the day, they receive a greater credit for future projected calories than they would if it was late at night (simply because they have more time to reach their average, and thus are more likely to do so.)
                // I am writing this comment because I forgot what this was, but knew it was here for some purpose, but didn't want to remove it.
                actQuot = (Double(curActive) / Double(averageBurn)) + (1 - getPercentOfDayDone())
                
                // Pass this, plus the user's remaining from average, to the weighting function to get the final projection.
                return (value: weightActiveProjection(input: remainingFromAvg, actQuot: actQuot), wasEstimate: wasEstimate)
            } else {
                return (value: Int(Double(1440 - minutesIntoDay()) * (Double(settingsObj.manualActive) / 1440)), wasEstimate: wasEstimate)
            }
        }
    }
    
    /// Pull the user's activity rings from HealthKit.
    func getActivitySummary() async -> HKActivitySummary {
        let calendar = Calendar.current
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.calendar = calendar

        let activitySummaries: [HKActivitySummary] = await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForActivitySummary(with: startDateComponents)
            let query = HKActivitySummaryQuery(predicate: predicate) { (query, summariesOrNil, errorOrNil) -> Void in
                if errorOrNil != nil {
                    continuation.resume(returning: [HKActivitySummary()])
                    return
                }
                continuation.resume(returning: summariesOrNil ?? [])
            }
            healthStore.execute(query)
        }
        return activitySummaries.first ?? HKActivitySummary()
    }
    
    func saveHKSample(value: Double, unit: HKUnit, type: HKQuantityType, date: Date) async -> UUID? {
        guard healthStore.authorizationStatus(for: type) == .sharingAuthorized else { return nil }
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        do {
            try await healthStore.save(sample)
            return sample.uuid
        } catch {
            return nil
        }
    }

    func deleteHKSample(uuid: UUID, type: HKQuantityType) async {
        guard healthStore.authorizationStatus(for: type) == .sharingAuthorized else { return }
        let predicate = HKQuery.predicateForObjects(with: [uuid])
        do {
            try await healthStore.deleteObjects(of: type, predicate: predicate)
        } catch {
            // Not recoverable.
        }
    }
    
    func addCalories(calories: Int, narrative: String?, date: Date, meal: UUID) async {
        let hkUUID = await saveHKSample(value: Double(calories), unit: .kilocalorie(), type: eatenQuantityType, date: date)
        let logNarrative = (narrative?.isEmpty ?? true) ? "Quick calories" : narrative!
        let newEntry = CalorieEntry(date: date, calories: calories, narrative: logNarrative, mealUUID: meal, isInHK: hkUUID != nil, healthKitUUID: hkUUID)
        await calorieActor.insertNewCals(object: newEntry)
    }
    
    func addWater(amount: Int, datetime: Date) async {
        let hkUUID = await saveHKSample(value: Double(amount), unit: .literUnit(with: .milli), type: waterQuantityType, date: datetime)
        let newWaterObj = WaterEntry(quantity: amount, healthKitUUID: hkUUID, date: datetime)
        await waterActor.addWater(object: newWaterObj)
    }
    
    func getAverageDeficitForPastWeek() async -> Int {
        let today = getStartOfDay(date: Date())
        let startQuery = getWeekBeforeDate(date: today)
        let eatenCals = await pullEatenCalories(startDate: startQuery, endDate: today)
        // It's safe to divide this by seven because today and startQuery will always be 7 days apart
        let averageEaten = (eatenCals.hk + eatenCals.budgie) / 7
        let averageResting = await getAverageCalories(from: startQuery, to: today, type: basalQuantityType).val
        let averageActive = await getAverageCalories(from: startQuery, to: today, type: activeQuantityType).val
        
        let totalDeficit = (averageResting + averageActive) - averageEaten
        return totalDeficit
    }
    
    func getLatestWeight() async -> (first: Double, second: Double, firstDate: Date?, secondDate: Date?) {
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())
            let recencyPredicate = HKQuery.predicateForSamples(withStart: cutoff, end: nil, options: [])

            return await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: weightSampleType, predicate: recencyPredicate, limit: 2, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if error != nil {
                    continuation.resume(returning: (first: 0, second: 0, firstDate: nil, secondDate: nil))
                } else {
                    var doubleFirstWeight: Double = 0
                    var doubleSecondWeight: Double = 0
                    var firstDate: Date? = nil
                    var secondDate: Date? = nil
                    let firstSample = samples?.first as? HKQuantitySample
                    let secondSample = samples?.last as? HKQuantitySample
                    if firstSample != nil {
                        firstDate = firstSample?.startDate
                        doubleFirstWeight = firstSample?.quantity.doubleValue(for: .gram()) ?? 0
                        doubleFirstWeight = roundDoubleWeight(input: doubleFirstWeight / 1000)
                    }
                    if secondSample != nil {
                        secondDate = secondSample?.startDate
                        doubleSecondWeight = secondSample?.quantity.doubleValue(for: .gram()) ?? 0
                        doubleSecondWeight = roundDoubleWeight(input: doubleSecondWeight / 1000)
                    }
                    continuation.resume(returning: (first: doubleFirstWeight, second: doubleSecondWeight, firstDate: firstDate, secondDate: secondDate))
                }
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches weight samples written to healthKit by Budgie Diet, newest first.
    func fetchBudgieWeightSamples(from: Date, to: Date) async -> [HKQuantitySample] {
        let ownSource = HKQuery.predicateForObjects(from: HKSource.default())
        let time = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictEndDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [ownSource, time])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: weightSampleType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: healthStore)) ?? []
    }

    /// Fetches weight samples written to healthKit by other apps, newest first.
    func fetchOtherWeightSamples(from: Date, to: Date) async -> [HKQuantitySample] {
        let time = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictEndDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate, time])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: weightSampleType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: healthStore)) ?? []
    }
    
    func getWaterOnDate(date: Date) async -> (hk: Int, bd: Int) {
        let startDate = getStartOfDay(date: date)
        let endDate = getMidnightOnDayAfter(date: startDate)

        let budgieEntries = await waterActor.getEntriesOnDate(date: startDate)
        let waterTotalInBudgie = budgieEntries.reduce(0) { $0 + $1.quantity }
        let mirrored = Set(budgieEntries.compactMap(\.healthKitUUID))

        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
        var subpredicates: [NSPredicate] = [notBudgiePredicate, timePredicate]
        if !mirrored.isEmpty {
            subpredicates.append(NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(with: mirrored)))
        }
        let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        let waterToday = HKSamplePredicate.quantitySample(type: waterQuantityType, predicate: queryPredicate)
        let sumWaterQuery = HKStatisticsQueryDescriptor(predicate: waterToday, options: .cumulativeSum)
        var waterTotalInHealthKit = 0
        if let queryResult = try? await sumWaterQuery.result(for: healthStore)?.sumQuantity() {
            waterTotalInHealthKit = Int(queryResult.doubleValue(for: HKUnit.literUnit(with: .milli)))
        }

        return (waterTotalInHealthKit, waterTotalInBudgie)
    }

    /// Returns an array of WeightPoints that represent weight entries over a period of time. Does not distinguish between Budgie Diet and non-Budgie Diet weight entries.
    func weightSeries(from: Date, to: Date) async -> [WeightPoint] {
        let everyDay = DateComponents(day: 1)
        let timePredicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictEndDate)
        // NB: deliberately NO notBudgiePredicate — see caveat below.
        return await withCheckedContinuation { continuation in
            let statQuery = HKStatisticsCollectionQuery(
                quantityType: weightSampleType,
                quantitySamplePredicate: timePredicate,
                options: .discreteAverage,
                anchorDate: from,
                intervalComponents: everyDay
            )
            statQuery.initialResultsHandler = { _, results, _ in
                guard let results else { continuation.resume(returning: []); return }
                var points: [WeightPoint] = []
                results.enumerateStatistics(from: from, to: to) { stat, _ in
                    if let q = stat.averageQuantity() {
                        points.append(WeightPoint(date: stat.startDate,
                                                  kilos: q.doubleValue(for: .gramUnit(with: .kilo))))
                    }
                }
                continuation.resume(returning: points)
            }
            healthStore.execute(statQuery)
        }
    }
    
    /// Distinct days within the range that have any eaten-calorie data — from HealthKit (any source) or Budgie Diet's own store. Used to decide whether food logging is consistent enough to draw conclusions from.
    func daysWithFoodLogged(from: Date, to: Date) async -> Int {
        let calendar = Calendar.current
        var loggedDays = Set<Date>()

        // Budgie Diet's own entries.
        let budgieEntries = await calorieActor.fetchCalsBetween(from: from, to: to)
        for entry in budgieEntries {
            loggedDays.insert(calendar.startOfDay(for: entry.date))
        }

        // HealthKit eaten samples from any source (includes other apps and Budgie's own mirrored samples).
        let timePredicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictEndDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: eatenQuantityType, predicate: timePredicate)],
            sortDescriptors: []
        )
        if let samples = try? await descriptor.result(for: healthStore) {
            for sample in samples {
                loggedDays.insert(calendar.startOfDay(for: sample.startDate))
            }
        }

        return loggedDays.count
    }
    
    /// Main function that updates the "todayLump" that contains up to the minute data and underpins the main screen.
    @MainActor func updateLump(todayLump: TodayLump, reloadWidgets: Bool = true) async {
        // If an update is already running, flag that another pass is needed once this one
        // finishes, rather than silently dropping this request.
        if todayLump.updateInProgress {
            todayLump.updateQueued = true
            return
        }
        
        // Turn on the "updating" flag to prevent conflicts
        todayLump.updateInProgress = true
        
        defer {
            todayLump.updateInProgress = false
            if todayLump.updateQueued {
                todayLump.updateQueued = false
                Task { await updateLump(todayLump: todayLump, reloadWidgets: reloadWidgets) }
            }
        }
        
        // Set up date variables for ease
        let today = Date()
        let todayStart = getStartOfDay(date: today)
        let todayEnd = getMidnightOnDayAfter(date: todayStart)        
        let calendar = Calendar.current
        let recentWeekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart     // last 7 days, incl. today
        let previousWeekStart = calendar.date(byAdding: .day, value: -13, to: todayStart) ?? todayStart   // the 7 days before that
        
        // Kick every independent query off concurrently. These fan out across HealthKit and the
        // calorie actor: the HK queries run in parallel, and the actor serialises its own work safely.
        async let eatenTask        = pullEatenCalories(startDate: todayStart, endDate: todayEnd)
        async let foodListTask     = calorieActor.fetchCalsBetween(from: todayStart, to: todayEnd)
        async let projBasalTask    = getProjBasalCalories()
        async let projActiveTask   = getProjActiveCalories()
        async let recBasalTask     = pullCalorieTotalForDate(date: today, type: basalQuantityType, hkOnly: true)
        async let recActiveTask    = pullCalorieTotalForDate(date: today, type: activeQuantityType, hkOnly: true)
        async let weightsTask      = getLatestWeight()
        async let avgDeficitTask   = getAverageDeficitForPastWeek()
        async let lastWeekAvgTask  = getAverageWeight(from: recentWeekStart, to: todayEnd)
        async let prevWeekAvgTask  = getAverageWeight(from: previousWeekStart, to: recentWeekStart)
        async let foodDaysTask     = daysWithFoodLogged(from: previousWeekStart, to: todayEnd)
        async let waterTask        = getWaterOnDate(date: todayStart)
        async let activityTask     = getActivitySummary()

        // Food eaten today
        let eatenCalories = await eatenTask
        todayLump.eatenCalories = eatenCalories.hk + eatenCalories.budgie
        todayLump.healthKitCalories = eatenCalories.hk

        // Food list + meal breakdown (the meal list depends on the fetched food list)
        let foodList = await foodListTask
        todayLump.foodList = foodList
        todayLump.allMeals = await calorieActor.getListOfMeals()
        todayLump.cleansedMealList = await calorieActor.cleansedMealList(data: foodList)

        todayLump.mealTotalList = [:]
        for meal in todayLump.cleansedMealList {
            var sum = 0
            for food in foodList where food.meal == meal.mealUUID {
                sum += food.calories
            }
            todayLump.mealTotalList[meal.mealUUID] = sum
        }

        // Projected burn (needed before the estimated-fallback branches below)
        todayLump.projectedBasal = await projBasalTask
        todayLump.projectedActive = await projActiveTask.value
        let projActiveEstimate = await projActiveTask.wasEstimate

        // Recorded basal — fall back to the manual figure if HealthKit has none
        let recBasalCalories = await recBasalTask
        if recBasalCalories != 0 {
            todayLump.basalEstimated = false
            todayLump.basalCalories = recBasalCalories
        } else {
            todayLump.basalEstimated = true
            todayLump.basalCalories = max(settingsObj.manualBMR - todayLump.projectedBasal, 0)
        }

        // Recorded active — fall back to the manual figure if HealthKit has none
        let recActiveCalories = await recActiveTask
        if recActiveCalories == 0 && projActiveEstimate {
            todayLump.activeEstimated = true
            todayLump.activeCalories = max(settingsObj.manualActive - todayLump.projectedActive, 0)
        } else {
            todayLump.activeEstimated = false
            todayLump.activeCalories = recActiveCalories
        }

        todayLump.recalculateBudget()

        // Weight + deficit history
        let weightsToday = await weightsTask
        todayLump.weightToday = weightsToday.first
        todayLump.weightYesterday = weightsToday.second
        todayLump.lastWeightDate = weightsToday.firstDate
        todayLump.prevWeightDate = weightsToday.secondDate
        todayLump.averageDeficit = await avgDeficitTask
        todayLump.lastWeekAvgWeight = await lastWeekAvgTask
        todayLump.prevWeekAvgWeight = await prevWeekAvgTask
        todayLump.foodDaysLoggedFortnight = await foodDaysTask

        // Water
        let waterDetails = await waterTask
        todayLump.waterToday = waterDetails.bd + waterDetails.hk

        // Activity rings
        todayLump.activitySummary = await activityTask

        todayLump.lastUpdate = Date()
        if reloadWidgets {
            // Mirror the numbers the widget needs into the shared app-group defaults.
            // The widget can't reliably run HealthKit/SwiftData work or read iCloud
            // key-value settings in its own process, so it renders from this snapshot.
            if let group = UserDefaults(suiteName: "group.JoeBaldwin.Budgie") {
                group.set(todayLump.totalBudget, forKey: "widgetTotalBudget")
                group.set(todayLump.eatenCalories, forKey: "widgetEatenCalories")
                group.set(todayLump.projectedBasal, forKey: "widgetProjectedBasal")
                group.set(settingsObj.finalMealTime, forKey: "widgetFinalMealTime")
                group.set(settingsObj.surplusMode, forKey: "widgetSurplusMode")
                group.set(settingsObj.useMealAllocations, forKey: "widgetUseAllocations")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    /// Sets up HealthKit observer queries to trigger updates to the TodayLump if the app sees new active, basal or eaten calories, weight entries, or new water entries.
    func setUpObserverQueries(todayLump: TodayLump) {
        for sampleType in [activeQuantityType, basalQuantityType, eatenQuantityType, waterQuantityType, weightSampleType] {
            // Ask HealthKit to wake the app when this type changes, even while backgrounded.
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { success, error in
                if let error { print("Background delivery failed for \(sampleType): \(error)") }
            }

            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, errorOrNil in
                guard errorOrNil == nil else {
                    completionHandler()          // still must acknowledge, even on error
                    return
                }
                Task {
                    await self.updateLump(todayLump: todayLump)   // ends with reloadAllTimelines()
                    completionHandler()          // tell HealthKit we've handled it
                }
            }
            healthStore.execute(query)
        }
    }
    
    func setUpRemoteChangeObserver(todayLump: TodayLump) {
        NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { _ in
            Task { await self.updateLump(todayLump: todayLump) }
        }
    }
    #endif
}


