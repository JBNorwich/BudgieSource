//
//  HealthData.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 19/08/2024.
//

import Foundation
import HealthKitUI
import Observation
import SwiftUI
import SwiftData

class HealthData {
    let calorieMealConfig = ModelConfiguration(schema: Schema([CalorieEntry.self,Meal.self]))
    let waterConfig = ModelConfiguration("waterDB", schema: Schema([WaterEntry.self]))
    let modelContainer: ModelContainer
    let calorieActor: CalorieActor
    let waterActor: WaterActor
    
    init() {
        modelContainer = try! ModelContainer(for: CalorieEntry.self, Meal.self, WaterEntry.self, configurations: calorieMealConfig, waterConfig)
        calorieActor = CalorieActor(modelContainer: modelContainer)
        waterActor = WaterActor(modelContainer: modelContainer)
    }
    
    func pullCalorieTotalTodayFromHK(type: HKQuantityType) async -> Int {
        do {
            let todayPredicate = getTodayPredicate()
            let calsToday = HKSamplePredicate.quantitySample(type: type, predicate: todayPredicate)
            let query: HKStatisticsQueryDescriptor = try await withCheckedThrowingContinuation { continuation in
                let sumActCalsQuery = HKStatisticsQueryDescriptor(predicate: calsToday, options: .cumulativeSum)
                continuation.resume(returning: sumActCalsQuery)
            }
            do {
                let queryResult = try await query.result(for: healthStore)?.sumQuantity()
                let kcals = queryResult?.doubleValue(for: HKUnit.kilocalorie()).rounded() ?? 0
                return Int(kcals)
            } catch {
                return 0
            }
        } catch {
            return 0
        }
    }
    
    ///Grabs the calorie total for a given date range and type from HealthKit and (for eaten) Budgie Diet. If manual mode is on, will return either the manual BMR/active amounts or, for eaten calories, just the amount of Budgie Diet calories. You must normalise the date to 00:00 before passing the date. Set hkOnly to true if you only care about HealthKit calories.
    func pullCalorieTotalForDate(date: Date, type: HKQuantityType, hkOnly: Bool) async -> Int {
        var calories: Double = 0
        let startDate = getStartOfDay(date: date)
        let endDate = getMidnightOnDayAfter(date: startDate)
        
        if type == eatenQuantityType && hkOnly == false {
            var budgieCalories: Int = 0
            let budgieResults = await calorieActor.fetchCalsBetween(from: date, to: endDate)
            if budgieResults.count != 0 {
                for result in budgieResults {
                    budgieCalories += result.calories
                }
            }
            calories = Double(budgieCalories)
        }
        
        do {
            let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
            let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,timePredicate])
            let calsToday = HKSamplePredicate.quantitySample(type: type, predicate: queryPredicate)
            let query: HKStatisticsQueryDescriptor = try await withCheckedThrowingContinuation { continuation in
                let sumActCalsQuery = HKStatisticsQueryDescriptor(predicate: calsToday, options: .cumulativeSum)
                continuation.resume(returning: sumActCalsQuery)
            }
            do {
                let kcals = try await query.result(for: healthStore)?.sumQuantity()
                calories += kcals?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
            } catch {
                calories += 0
            }
        } catch {
            calories += 0
        }
        calories = calories.rounded()
        
        return Int(calories)
    }
    
    func pullEatenCalories(startDate: Date, endDate: Date) async -> (hk: Int, budgie: Int, total: Int) {
        var budgieCalories: Int = 0
        var healthKitcalories: Double = 0
        
        // get HealthKit calories
        do {
            let notBudgieTodayPredicate = getNotBudgieTodayPredicate()
            let query: HKSampleQueryDescriptor<HKQuantitySample> = try await withCheckedThrowingContinuation { continuation in
                let descriptor = HKSampleQueryDescriptor(predicates:[.quantitySample(type: eatenQuantityType, predicate: notBudgieTodayPredicate)], sortDescriptors: [])
                continuation.resume(returning: descriptor)
            }
            do {
                let results = try await query.result(for: healthStore)
                for result in results {
                    let source = result.sourceRevision.source
                    if source != HKSource.default() {
                        //Note to self: You need to total the doubleValues and *then* convert to Int as otherwise it gives very annoying rounding errors
                        healthKitcalories += result.quantity.doubleValue(for: HKUnit.kilocalorie())
                    }
                }
            } catch {
                healthKitcalories = 0
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
        
        return (hk: Int(healthKitcalories), budgie: budgieCalories, total: Int(healthKitcalories) + budgieCalories)
    }
    
    func getProjBasalCalories() async -> Int {
        var avgBasalCals = Int()

        let endDate = getStartOfDay(date: Date())
        let startDate = getWeekBeforeDate(date: endDate)
        avgBasalCals = await self.getAverageCalories(from: startDate, to: endDate, type: basalQuantityType).val
        
        let remainingMinsInDay = 1440 - minutesIntoDay()
        let calsPerMinute: Double = Double(avgBasalCals) / 1440
        let projectedCals = Double(remainingMinsInDay) * calsPerMinute
        return Int(projectedCals)
    }
    
    func getAverageWeight(from: Date, to: Date) async -> Double {
        let everyDay = DateComponents(day:1)
        
        do {
            let timePredicate = HKQuery.predicateForSamples(withStart: from, end: to, options: HKQueryOptions.strictEndDate)
            let searchPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,timePredicate])
            
            return await withCheckedContinuation { continuation in
                let statQuery = HKStatisticsCollectionQuery(quantityType: weightSampleType, quantitySamplePredicate: searchPredicate, options: .discreteAverage, anchorDate: from, intervalComponents: everyDay)
                
                statQuery.initialResultsHandler = { query, results, error in
                    guard let actCollection = results else {
//                        assertionFailure("")
                        continuation.resume(returning: 0)
                        return
                    }
                    
                    var daysInSample: Double = 0
                    var totalWeight: Double = 0
                    
                    actCollection.enumerateStatistics(from: from, to: to) { statistics, _ in
                        if let quantity = statistics.averageQuantity() {
                            print(quantity.doubleValue(for: .gram()).formatted())
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
    }
    
    func getAverageCalories(from: Date, to: Date, type: HKQuantityType) async -> (val: Int, estimate: Bool) {
        let everyDay = DateComponents(day:1)
        
        do {
            let timePredicate = HKQuery.predicateForSamples(withStart: from, end: to, options: HKQueryOptions.strictEndDate)
            let searchPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,timePredicate])
            return await withCheckedContinuation { continuation in
                
                let statQuery = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: searchPredicate, options: .cumulativeSum, anchorDate: from, intervalComponents: everyDay)
                
                statQuery.initialResultsHandler = { query, results, error in
                    guard let actCollection = results else {
//                        assertionFailure("")
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
                    
                    if daysInSample < 7 {
                        let diff = 7 - daysInSample
                        var toAdd: Int = 0
                        
                        if type == .quantityType(forIdentifier: .activeEnergyBurned) {
                            toAdd = settingsObj.manualActive
                        } else if type == .quantityType(forIdentifier: .basalEnergyBurned) {
                            toAdd = settingsObj.manualBMR
                        }
                        
                        totalCals = totalCals + (diff * toAdd)
                        estimated = true
                    }
                    
                    let average = totalCals/7
                    
                    continuation.resume(returning: (val: average, estimate: estimated))
                }
                
                healthStore.execute(statQuery)
            }
        }
    }
    
    func getProjActiveCalories() async -> Int {
        var averageBurn: Int = 0
        var wasEstimate: Bool = false
        var remainingFromAvg: Int = 0
        var actQuot: Double = 1
        let endDate = getStartOfDay(date: Date())
        let startDate = getWeekBeforeDate(date: endDate)
        let curActive = await pullCalorieTotalTodayFromHK(type: activeQuantityType)
        
        if settingsObj.useFitnessGoal != true {
            let result = await self.getAverageCalories(from: startDate, to: endDate, type: activeQuantityType)
            if result.estimate == false {
                averageBurn = result.val
            } else {
                averageBurn = settingsObj.manualActive
                wasEstimate = true
            }
            remainingFromAvg = averageBurn - curActive

        } else {
            averageBurn = await getMoveGoal()
            if curActive != 0 {
                remainingFromAvg = averageBurn - curActive
            } else {
                remainingFromAvg = averageBurn - Int(Double(minutesIntoDay()) * (Double(settingsObj.manualActive) / 1440))
            }
        }
        
        if curActive > averageBurn {
            actQuot = 1
        } else {
            actQuot = (Double(curActive) / Double(averageBurn)) + (1 - getPercentOfDayDone())
        }
        
        if remainingFromAvg < 0 {
            return 0
        } else {
            if wasEstimate == false {
                return weightActiveProjection(input: remainingFromAvg, style: nil, timeInput: nil, actQuot: actQuot)
            } else {
                return Int(Double(1440 - minutesIntoDay()) * (Double(settingsObj.manualActive) / 1440))
            }
        }
    }
    
    func getActivitySummary() async -> HKActivitySummary {
        let calendar = NSCalendar.current
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.calendar = calendar

        let activitySummaries: [HKActivitySummary] = await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForActivitySummary(with: startDateComponents)
            let query = HKActivitySummaryQuery(predicate: predicate) { (query, summariesOrNil, errorOrNil) -> Void in
                if errorOrNil != nil {
                    continuation.resume(returning: [HKActivitySummary()])
                    return
                }
                continuation.resume(returning: summariesOrNil!)
            }
            healthStore.execute(query)
        }
        return activitySummaries.first ?? HKActivitySummary()
    }
    
    func getMoveGoal() async -> Int {
        let summary = await getActivitySummary()
        return Int(summary.activeEnergyBurnedGoal.doubleValue(for: HKUnit.kilocalorie()))
    }
    
    func addCalories(calories: Int, narrative: String?, date: Date, meal: UUID) async {
        var dateOfEntry: Date
        var narrativeToLog: String
        
        dateOfEntry = date
        
        var didHK = Bool()
        var hkUUID: UUID = UUID()
        let authStatus = healthStore.authorizationStatus(for: eatenQuantityType)
        if authStatus == HKAuthorizationStatus.sharingAuthorized {
            let quantityUnit = HKUnit(from:.kilocalorie)
            let quantityAmount = HKQuantity(unit: quantityUnit, doubleValue:Double(calories))
            let sample = HKQuantitySample(type: eatenQuantityType, quantity: quantityAmount, start: dateOfEntry, end: dateOfEntry)
            hkUUID = sample.uuid
            do {
                try await healthStore.save(sample)
            } catch {
                // handle errors here
            }
            didHK = true
        } else {
            didHK = false
        }
        if (narrative != "") && (narrative != nil) {
            narrativeToLog = narrative!
        } else {
            narrativeToLog = "Quick calories"
        }
        
        if didHK == true {
            let newCalorieObj: CalorieEntry = CalorieEntry(date: dateOfEntry, calories: calories, narrative: narrativeToLog, mealUUID: meal, isInHK: true, healthKitUUID: hkUUID)
            await calorieActor.insertNewCals(object: newCalorieObj)
        } else {
            let newCalorieObj: CalorieEntry = CalorieEntry(date: dateOfEntry, calories: calories, narrative: narrativeToLog, mealUUID: meal, isInHK: false, healthKitUUID: nil)
            //await... removed
            await calorieActor.insertNewCals(object: newCalorieObj)
        }
    }
    
    func addWater(amount: Int, datetime: Date) async {
        var hkUUID: UUID?
        let authStatus = healthStore.authorizationStatus(for: waterQuantityType)
        if authStatus == HKAuthorizationStatus.sharingAuthorized {
            let quantityAmount = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: Double(amount))
            let sample = HKQuantitySample(type: waterQuantityType, quantity: quantityAmount, start: datetime, end: datetime)
            hkUUID = sample.uuid
            do {
                try await healthStore.save(sample)
            } catch {
                //errorhandling
            }
        }
        let newWaterObj = WaterEntry(date: datetime, quantity: amount, healthKitUUID: hkUUID ?? nil)
        await waterActor.addWater(object: newWaterObj)
    }
    
    func getAverageDeficitForPastWeek() async -> Int {
        let today = getStartOfDay(date: Date())
        let startQuery = getWeekBeforeDate(date: today)
        let eatenCals = await pullEatenCalories(startDate: startQuery, endDate: today)
        let averageEaten = eatenCals.total / 7
        let averageResting = await getAverageCalories(from: startQuery, to: today, type: basalQuantityType).val
        let averageActive = await getAverageCalories(from: startQuery, to: today, type: activeQuantityType).val
        
        let totalDeficit = (averageResting + averageActive) - averageEaten
        return totalDeficit
    }
    
    func getDeficitForDate(date: Date) async -> Int {
        let eatenCals = await pullEatenCalories(startDate: getStartOfDay(date: date), endDate: getMidnightOnDayAfter(date: date))
        let basalCals = await pullCalorieTotalForDate(date: date, type: basalQuantityType, hkOnly: false)
        let activeCals = await pullCalorieTotalForDate(date: date, type: activeQuantityType, hkOnly: false)
        let deficit = basalCals + activeCals - eatenCals.total
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
    
    func getWaterToday() async -> Int {
        do {
            let todayPredicate = getTodayPredicate()
            let waterToday = HKSamplePredicate.quantitySample(type: waterQuantityType, predicate: todayPredicate)
            let query: HKStatisticsQueryDescriptor = try await withCheckedThrowingContinuation { continuation in
                let sumWaterQuery = HKStatisticsQueryDescriptor(predicate: waterToday, options: .cumulativeSum)
                continuation.resume(returning: sumWaterQuery)
            }
            do {
                let queryResult = try await query.result(for: healthStore)?.sumQuantity()
                let ml = queryResult?.doubleValue(for: HKUnit.literUnit(with: .milli)) ?? 0
                return Int(ml)
            } catch {
                return 0
            }
        } catch {
            return 0
        }
    }
    
    func getWaterOnDate(date: Date) async -> (hk: Int, bd: Int) {
        var hk: Int = 0
        var bd: Int = 0
        
        let startDate = getStartOfDay(date: date)
        let endDate = getMidnightOnDayAfter(date: startDate)
    
        do {
            let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
            let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,timePredicate])
            let waterToday = HKSamplePredicate.quantitySample(type: waterQuantityType, predicate: queryPredicate)
            let query: HKStatisticsQueryDescriptor = try await withCheckedThrowingContinuation { continuation in
                let sumWaterQuery = HKStatisticsQueryDescriptor(predicate: waterToday, options: .cumulativeSum)
                continuation.resume(returning: sumWaterQuery)
            }
            do {
                let queryResult = try await query.result(for: healthStore)?.sumQuantity()
                let ml = queryResult?.doubleValue(for: HKUnit.literUnit(with: .milli)) ?? 0
                hk = Int(ml)
            } catch {
                hk = 0
            }
        } catch {
            hk = 0
        }
        
        bd = await waterActor.getTotalOnDate(date: date)
        
        return (hk, bd)
    }
    
    @MainActor func updateLump(todayLump: TodayLump) async {
        if todayLump.updateInProgress == false {
            todayLump.updateInProgress = true
            let todayStart = getStartOfDay(date: Date())
            let todayEnd = getMidnightOnDayAfter(date: todayStart)
            let weekBeforeYesterday = getWeekBeforeDate(date: getMidnightOnDayBefore(date: todayStart))
            let weekBeforeWeekBeforeYesterday = getWeekBeforeDate(date: weekBeforeYesterday)
            
            let eatenCalories = await pullEatenCalories(startDate: todayStart, endDate: todayEnd)
            todayLump.eatenCalories = eatenCalories.total
            todayLump.foodList = await calorieActor.fetchCalsBetween(from: todayStart, to: todayEnd)
            todayLump.healthKitCalories = eatenCalories.hk
            todayLump.mealList = await calorieActor.cleansedMealList(data: todayLump.foodList)
            
            for meal in todayLump.mealList {
                var sum: Int = 0
                for food in todayLump.foodList where food.meal == meal.mealUUID {
                    sum = sum + food.calories
                }
                todayLump.mealTotalList[meal.mealUUID] = sum
            }
            
            todayLump.desiredDeficit = settingsObj.desiredDeficit
            todayLump.projectedBasal = await getProjBasalCalories()
            todayLump.projectedActive = await getProjActiveCalories()
            let weightsToday = await getLatestWeight()
            todayLump.weightToday = weightsToday.first
            todayLump.weightYesterday = weightsToday.second
            todayLump.lastWeightDate = weightsToday.firstDate
            print("Today: \(todayLump.weightToday.formatted())")
            print("Yesterday: \(todayLump.weightYesterday.formatted())")
            todayLump.yesterdayDeficit = await getDeficitForDate(date: getMidnightOnDayBefore(date: Date()))
            todayLump.averageDeficit = await getAverageDeficitForPastWeek()
            todayLump.lastWeekAvgWeight = await getAverageWeight(from: weekBeforeYesterday, to: todayEnd)
            todayLump.prevWeekAvgWeight = await getAverageWeight(from: weekBeforeWeekBeforeYesterday, to: getWeekBeforeDate(date: todayEnd))
            
            let recBasalCalories = await pullCalorieTotalTodayFromHK(type: basalQuantityType)
            let recActiveCalories = await pullCalorieTotalTodayFromHK(type: activeQuantityType)
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
            
            let waterDetails = await getWaterOnDate(date: todayStart)
            todayLump.waterToday = waterDetails.bd + waterDetails.hk
            todayLump.activitySummary = await getActivitySummary()

            todayLump.lastUpdate = Date()
            todayLump.updateInProgress = false
        }
    }
    
    func setUpObserverQueries(todayLump: TodayLump) {
        let activeQuery = HKObserverQuery(sampleType: activeQuantityType, predicate: observerPredicate){ (query, completionHandler, errorOrNil) in
            if errorOrNil != nil {
                // Properly handle the error.
                return
            }
            Task {
                await self.updateLump(todayLump: todayLump)
            }
        }
        let basalQuery = HKObserverQuery(sampleType: basalQuantityType, predicate: observerPredicate){ (query, completionHandler, errorOrNil) in
            if errorOrNil != nil {
                // Properly handle the error.
                return
            }
            Task {
                await self.updateLump(todayLump: todayLump)
            }
        }
        
        let eatenQuery = HKObserverQuery(sampleType: eatenQuantityType, predicate: observerPredicate){ (query, completionHandler, errorOrNil) in
            if errorOrNil != nil {
                return
            }
            Task {
                await self.updateLump(todayLump: todayLump)
            }
        }
        let waterQuery = HKObserverQuery(sampleType: waterQuantityType, predicate: observerPredicate){ (query, completionHandler, errorOrNil) in
            if errorOrNil != nil {
                // Properly handle the error.
                return
            }
            Task {
                await self.updateLump(todayLump: todayLump)
            }
        }
       
        healthStore.execute(activeQuery)
        healthStore.execute(basalQuery)
        healthStore.execute(eatenQuery)
        healthStore.execute(waterQuery)
    }
}


