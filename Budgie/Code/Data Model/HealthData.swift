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
import HealthKitUI
import Observation
import SwiftUI
import SwiftData
import WidgetKit

/// HealthData is a "god object" which acts as the main data store for the application. There should only ever be one instance of HealthData, which is instantiated at app start as "dataStore". You should never call HealthData(), subclass it or create a new object from it.
final class HealthData {
    static let shared = HealthData()
    
    let calorieMealConfig = ModelConfiguration(schema: Schema([CalorieEntry.self,Meal.self]), cloudKitDatabase: .private("iCloud.com.JoeBaldwin.Budgie.data"))
    let waterConfig = ModelConfiguration("waterDB", schema: Schema([WaterEntry.self]), cloudKitDatabase: .private("iCloud.com.JoeBaldwin.Budgie.data"))
    let modelContainer: ModelContainer
    let calorieActor: CalorieActor
    let waterActor: WaterActor
    private(set) var storeFailedToLoad = false
    
//    private init() {
//        modelContainer = try! ModelContainer(for: CalorieEntry.self, Meal.self, WaterEntry.self, configurations: calorieMealConfig, waterConfig)
//        calorieActor = CalorieActor(modelContainer: modelContainer)
//        waterActor = WaterActor(modelContainer: modelContainer)
//    }
    
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
    
    ///Grabs the calorie total for a given date and type from HealthKit and (for eaten) Budgie Diet. Will pull the total of entries from the start of the date passed to the start of the following day. Set hkOnly to true if you only care about HealthKit calories.
    func pullCalorieTotalForDate(date: Date, type: HKQuantityType, hkOnly: Bool) async -> Int {
        var calories: Double = 0
        let startDate = getStartOfDay(date: date)
        let endDate = getMidnightOnDayAfter(date: startDate)
        
        if type == eatenQuantityType && hkOnly == false {
            var budgieCalories: Int = 0
            let budgieResults = await calorieActor.fetchCalsBetween(from: date, to: endDate)
            if !budgieResults.isEmpty {
                for result in budgieResults {
                    budgieCalories += result.calories
                }
            }
            calories = Double(budgieCalories)
        }
        
        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
        let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,timePredicate])
        let calsToday = HKSamplePredicate.quantitySample(type: type, predicate: queryPredicate)
        let sumActCalsQuery = HKStatisticsQueryDescriptor(predicate: calsToday, options: .cumulativeSum)
        let kcals = (try? await sumActCalsQuery.result(for: healthStore))??.sumQuantity()
        calories += kcals?.doubleValue(for: .kilocalorie()) ?? 0
        
        calories = calories.rounded()
        
        return Int(calories)
    }
    
    /// Obtain the calories eaten from both Budgie Diet's internal storage and HealthKit. Returns a tuple of Ints that include HealthKit calories plus internal Budgie calories only.
    func pullEatenCalories(startDate: Date, endDate: Date) async -> (hk: Int, budgie: Int) {
        var budgieCalories: Int = 0
        var healthKitcalories: Double = 0
        
        // get HealthKit calories
        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate, timePredicate])
        let descriptor = HKSampleQueryDescriptor(predicates:[.quantitySample(type: eatenQuantityType, predicate: queryPredicate)], sortDescriptors: [])
        do {
            let results = try await descriptor.result(for: healthStore)
            for result in results {
                healthKitcalories += result.quantity.doubleValue(for: HKUnit.kilocalorie())
            }
        } catch {
            healthKitcalories = 0
        }
        
        // get Budgie Diet calories
        let budgieResults = await calorieActor.fetchCalsBetween(from: startDate, to: endDate)
        if budgieResults.count == 0 {
            budgieCalories = 0
        } else {
            for result in budgieResults {
                budgieCalories += result.calories
            }
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
        let searchPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,timePredicate])
        
        return await withCheckedContinuation { continuation in
            let statQuery = HKStatisticsCollectionQuery(quantityType: weightSampleType, quantitySamplePredicate: searchPredicate, options: .discreteAverage, anchorDate: from, intervalComponents: everyDay)
            
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
                
                let average: Double = (totalWeight/daysInSample)/1000
                
                continuation.resume(returning: roundDoubleWeight(input: average))
            }
            
            healthStore.execute(statQuery)
        }
    }
    
    func getAverageCalories(from: Date, to: Date, type: HKQuantityType) async -> (val: Int, estimate: Bool) {
        let everyDay = DateComponents(day:1)
        
        let timePredicate = HKQuery.predicateForSamples(withStart: from, end: to, options: HKQueryOptions.strictEndDate)
        let searchPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,timePredicate])
        return await withCheckedContinuation { continuation in
            
            let statQuery = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: searchPredicate, options: .cumulativeSum, anchorDate: from, intervalComponents: everyDay)
            
            statQuery.initialResultsHandler = { query, results, error in
                guard let actCollection = results else {
                    continuation.resume(returning:(val: 0, estimate: true))
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
                
                continuation.resume(returning: (val: average, estimate: estimated))
            }
            
            healthStore.execute(statQuery)
        }
    }
    
    func getProjActiveCalories() async -> Int {
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
            
            // If it's not an estimate, great, use that
            if result.estimate == false {
                averageBurn = result.val
                
            // If it is an estimate, use the user's manual calorie burn instead
            } else {
                averageBurn = settingsObj.manualActive
                wasEstimate = true
            }
        } else {
            // User wants to use their Move goal as the basis for their projections. Yank it from HealthKit
            let summary = await getActivitySummary()
            averageBurn = Int(summary.activeEnergyBurnedGoal.doubleValue(for: HKUnit.kilocalorie()))
        }
        // Remaining from average = how much more would user have to burn to reach their previous week's average?
        remainingFromAvg = averageBurn - curActive
        
        if remainingFromAvg < 0 {
            return 0
        } else {
            if wasEstimate == false {
                // Work out the user's Activity Quotient. This is the percentage of the user's averageBurn that is done, plus the percentage of the day that is left. This works this way to ensure that if the user does more exercise earlier in the day, they receive a greater credit for future projected calories than they would if it was late at night (simply because they have more time to reach their average, and thus are more likely to do so.)
                // I am writing this comment because I forgot what this was, but knew it was here for some purpose, but didn't want to remove it.
                actQuot = (Double(curActive) / Double(averageBurn)) + (1 - getPercentOfDayDone())
                
                // Pass this, plus the user's remaining from average, to the weighting function to get the final projection.
                return weightActiveProjection(input: remainingFromAvg, actQuot: actQuot)
            } else {
                return Int(Double(1440 - minutesIntoDay()) * (Double(settingsObj.manualActive) / 1440))
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
    
    func getDeficitForDate(date: Date) async -> Int {
        let eatenCals = await pullEatenCalories(startDate: getStartOfDay(date: date), endDate: getMidnightOnDayAfter(date: date))
        let basalCals = await pullCalorieTotalForDate(date: date, type: basalQuantityType, hkOnly: false)
        let activeCals = await pullCalorieTotalForDate(date: date, type: activeQuantityType, hkOnly: false)
        let deficit = basalCals + activeCals - eatenCals.hk - eatenCals.budgie
        return deficit
    }
    
    func getLatestWeight() async -> (first: Double, second: Double, firstDate: Date?, secondDate: Date?) {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightSampleType, predicate: nil, limit: 2, sortDescriptors: [sortDescriptor]) { _, samples, error in
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
    
    func getWaterOnDate(date: Date) async -> (hk: Int, bd: Int) {
        var waterTotalInHealthKit: Int = 0
        var waterTotalInBudgie: Int = 0
        
        let startDate = getStartOfDay(date: date)
        let endDate = getMidnightOnDayAfter(date: startDate)
    
        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
        let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,timePredicate])
        let waterToday = HKSamplePredicate.quantitySample(type: waterQuantityType, predicate: queryPredicate)
        let sumWaterQuery = HKStatisticsQueryDescriptor(predicate: waterToday, options: .cumulativeSum)
        do {
            let queryResult = try await sumWaterQuery.result(for: healthStore)?.sumQuantity()
            let ml = queryResult?.doubleValue(for: HKUnit.literUnit(with: .milli)) ?? 0
            waterTotalInHealthKit = Int(ml)
        } catch {
            waterTotalInHealthKit = 0
        }
        
        waterTotalInBudgie = await waterActor.getTotalOnDate(date: date)
        
        return (waterTotalInHealthKit, waterTotalInBudgie)
    }
    
    /// Main function that updates the "todayLump" that contains up to the minute data and underpins the main screen.
    @MainActor func updateLump(todayLump: TodayLump) async {
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
                Task { await updateLump(todayLump: todayLump) }
            }
        }
        
        // Set up date variables for ease
        let today = Date()
        let todayStart = getStartOfDay(date: today)
        let todayEnd = getMidnightOnDayAfter(date: todayStart)
        let weekBeforeYesterday = getWeekBeforeDate(date: getMidnightOnDayBefore(date: todayStart))
        let weekBeforeWeekBeforeYesterday = getWeekBeforeDate(date: weekBeforeYesterday)
        
        let eatenCalories = await pullEatenCalories(startDate: todayStart, endDate: todayEnd)
        todayLump.eatenCalories = eatenCalories.hk + eatenCalories.budgie
        todayLump.healthKitCalories = eatenCalories.hk
        todayLump.foodList = await calorieActor.fetchCalsBetween(from: todayStart, to: todayEnd)
        todayLump.mealList = await calorieActor.cleansedMealList(data: todayLump.foodList)
        
        // Calculate meal totals for the food list on the main page
        todayLump.mealTotalList = [:]
        for meal in todayLump.mealList {
            var sum: Int = 0
            for food in todayLump.foodList where food.meal == meal.mealUUID {
                sum = sum + food.calories
            }
            todayLump.mealTotalList[meal.mealUUID] = sum
        }
        
        // Pull in projected basal and active calories
        todayLump.projectedBasal = await getProjBasalCalories()
        todayLump.projectedActive = await getProjActiveCalories()
        
        // Pull in actual basal and active calories
        let recBasalCalories = await pullCalorieTotalForDate(date: today, type: basalQuantityType, hkOnly: true)
        let recActiveCalories = await pullCalorieTotalForDate(date: today, type: activeQuantityType, hkOnly: true)

        if recBasalCalories != 0 {
            todayLump.basalEstimated = false
            todayLump.basalCalories = recBasalCalories
        } else {
            todayLump.basalEstimated = true
            todayLump.basalCalories = settingsObj.manualBMR - todayLump.projectedBasal
        }
        if recActiveCalories != 0 {
            todayLump.activeEstimated = false
            todayLump.activeCalories = recActiveCalories
        } else {
            todayLump.activeEstimated = true
            todayLump.activeCalories = settingsObj.manualActive - todayLump.projectedActive
        }
        
        todayLump.recalculateBudget()
        
        // Obtaining weight information
        let weightsToday = await getLatestWeight()
        todayLump.weightToday = weightsToday.first
        todayLump.weightYesterday = weightsToday.second
        todayLump.lastWeightDate = weightsToday.firstDate
        todayLump.yesterdayDeficit = await getDeficitForDate(date: getMidnightOnDayBefore(date: Date()))
        todayLump.averageDeficit = await getAverageDeficitForPastWeek()
        todayLump.lastWeekAvgWeight = await getAverageWeight(from: weekBeforeYesterday, to: todayEnd)
        todayLump.prevWeekAvgWeight = await getAverageWeight(from: weekBeforeWeekBeforeYesterday, to: getWeekBeforeDate(date: todayEnd))
        
        // Pull in water
        let waterDetails = await getWaterOnDate(date: todayStart)
        todayLump.waterToday = waterDetails.bd + waterDetails.hk
        
        // Get user's Activity Rings
        todayLump.activitySummary = await getActivitySummary()

        todayLump.lastUpdate = Date()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Sets up HealthKit observer queries to trigger updates to the TodayLump if the app sees new active, basal or eaten calories, or new water entries.
    func setUpObserverQueries(todayLump: TodayLump) {
        for sampleType in [activeQuantityType, basalQuantityType, eatenQuantityType, waterQuantityType] {
            let query = HKObserverQuery(sampleType: sampleType, predicate: observerPredicate) { _, _, errorOrNil in
                guard errorOrNil == nil else { return }
                Task { await self.updateLump(todayLump: todayLump) }
            }
            healthStore.execute(query)
        }
    }
    
    func setUpRemoteChangeObserver(todayLump: TodayLump) {
        NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { _ in
            Task { await self.updateLump(todayLump: todayLump) }
        }
    }
}


