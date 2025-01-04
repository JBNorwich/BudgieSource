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

@Observable
class HealthData: ObservableObject {
    var dataUpdated: Bool = false // updater in func
    var forceRefresh: Bool = false
    var isBackgroundPing: Bool = false
    var lastUpdateRequestSource: String = String()
    var updateInProgress = false
    var calorieModel: CalorieData
    
    @MainActor init() {
        calorieModel = CalorieData()
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
            let budgieResults = self.calorieModel.fetchCalsBetween(from: date, to: endDate)
            if budgieResults.count != 0 {
                for result in budgieResults {
                    budgieCalories += result.calories
                }
            }
            calories = Double(budgieCalories)
        }
        
        if settingsObj.manualMode == false {
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
        } else {
            if hkOnly == false {
                switch type {
                case eatenQuantityType:
                    calories += 0
                case basalQuantityType:
                    calories += Double(settingsObj.manualBMR)
                case activeQuantityType:
                    calories += Double(settingsObj.manualActive)
                default:
                    calories += 0
                }
            } else {
                calories += 0
            }
        }
        return Int(calories)
    }
    
//    func pullCalorieTotalBetweenFromHK(start: Date, end: Date, type: HKQuantityType) async -> Int {
//        do {
//            let timePredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: HKQueryOptions.strictEndDate)
//            let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,timePredicate])
//            let calsToday = HKSamplePredicate.quantitySample(type: type, predicate: queryPredicate)
//            let query :HKStatisticsQueryDescriptor = try await withCheckedThrowingContinuation { continuation in
//                let sumActCalsQuery = HKStatisticsQueryDescriptor(predicate: calsToday, options: .cumulativeSum)
//                continuation.resume(returning: sumActCalsQuery)
//            }
//            do {
//                let kcals = try await query.result(for: healthStore)?.sumQuantity()
//                let calories = kcals?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
//                return Int(calories)
//            } catch {
//                return 0
//            }
//        } catch {
//            return 0
//        }
//    }
    
    func pullEatenCalories(startDate: Date, endDate: Date) async -> (hk: Int, budgie: Int, total: Int) {
        var budgieCalories: Int = 0
        var healthKitcalories: Double = 0
        
        // get HealthKit calories
        if settingsObj.manualMode == false {
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
        }
        
        // get Budgie Diet calories
        let budgieResults = self.calorieModel.fetchCalsBetween(from: startDate, to: endDate)
        if budgieResults.count == 0 {
            budgieCalories = 0
        } else {
            for result in budgieResults {
                budgieCalories += result.calories
            }
        }
        
        return (hk: Int(healthKitcalories), budgie: budgieCalories, total: Int(healthKitcalories) + budgieCalories)
    }
    
    func deleteCalorieEntries(calorieObjects: [CalorieEntry]) async
    {
        for object in calorieObjects {
            let hkUUID = object.healthKitUUID
            
            if hkUUID != nil {
                if healthStore.authorizationStatus(for: eatenQuantityType) == HKAuthorizationStatus.sharingAuthorized
                {
                    let hkUUIDPredicate = HKQuery.predicateForObjects(with: [hkUUID!])
                    
                    do {
                        try await healthStore.deleteObjects(of: eatenQuantityType, predicate: hkUUIDPredicate)
                    } catch {
                        //balls!
                    }
                }
            }
        }
        self.calorieModel.deleteEntries(objects: calorieObjects)
        self.lastUpdateRequestSource = "Deletion of calories"
        self.isBackgroundPing = false
        self.dataUpdated = true
    }
    
    func getCalorieEntries(date: Date) async -> [CalorieEntry]
    {
        let endDate = getMidnightOnDayAfter(date: date)
        var returnArray: [CalorieEntry] = []
        
        let budgieResults = self.calorieModel.fetchCalsBetween(from: date, to: endDate)
        
        if budgieResults.count != 0 {
            returnArray = budgieResults
        }
        
        return returnArray
    }
    
    func getProjBasalCalories() async -> Int {
        var avgBasalCals = Int()
        if settingsObj.manualMode == true {
            avgBasalCals = settingsObj.manualBMR
        } else {
            let endDate = getStartOfDay(date: Date())
            let startDate = getWeekBeforeDate(date: endDate)
            avgBasalCals = await self.getAverageCalories(from: startDate, to: endDate, type: basalQuantityType).val
        }
        let remainingMinsInDay = 1440 - minutesIntoDay()
        let calsPerMinute: Double = Double(avgBasalCals) / 1440
        let projectedCals = Double(remainingMinsInDay) * calsPerMinute
        return Int(projectedCals)
    }
    
    func getAverageCalories(from: Date, to: Date, type: HKQuantityType) async -> (val: Int, estimate: Bool) {
        let calendar = Calendar.current
        var estimated = false
        var calories: Double = 0
        var calsToAdd: Double = 0
        var earliestSample = Date()
        var latestSample = Date()
        var daysInSample = Int()
        
        do {
            let timePredicate = HKQuery.predicateForSamples(withStart: from, end: to, options: HKQueryOptions.strictEndDate)
            let searchPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,timePredicate])
            let query: HKSampleQueryDescriptor<HKQuantitySample> = try await withCheckedThrowingContinuation { continuation in
                let descriptor = HKSampleQueryDescriptor(predicates:[.quantitySample(type: type, predicate: searchPredicate)], sortDescriptors: [])
                continuation.resume(returning: descriptor)
            }
            do {
                let results = try await query.result(for: healthStore)
                for result in results {
                    calories += result.quantity.doubleValue(for: HKUnit.kilocalorie())
                    if result.endDate > latestSample
                    { latestSample = result.startDate }
                    if result.startDate < earliestSample
                    { earliestSample = result.startDate }
                }
                daysInSample = calendar.numberOfDaysBetween(earliestSample, and: latestSample)
                
                if daysInSample != 0 && type == basalQuantityType { daysInSample = daysInSample - 1 }
                
                if daysInSample == 0 {
                    estimated = true
                }
                
                if daysInSample < 7 {
                    let daysToAdd = 7 - daysInSample
                    var manualToAdd: Double
                    switch type {
                        case activeQuantityType: manualToAdd = Double(settingsObj.manualActive)
                        case basalQuantityType: manualToAdd = Double(settingsObj.manualBMR)
                        default: manualToAdd = 0
                    }
                    calsToAdd = Double(daysToAdd) * manualToAdd
                    daysInSample = 7
                }
                
                calories = (calsToAdd + calories) / Double(daysInSample)
            } catch {
                estimated = true
            }
        } catch {
            estimated = true
        }
        
        return (val: Int(calories), estimate: estimated)
    }
    
    func getProjActiveCalories() async -> Int {
        if settingsObj.manualMode == true {
            let projectedCals = Double(1440 - minutesIntoDay()) * (Double(settingsObj.manualActive) / 1440)
            return Int(projectedCals)
        } else {
            var averageBurn: Int = 0
            var wasEstimate: Bool = false
            var remainingFromAvg: Int = 0
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
                print("Averageburn = \(averageBurn)")
                if curActive != 0 {
                    remainingFromAvg = averageBurn - curActive
                } else {
                    remainingFromAvg = averageBurn - Int(Double(minutesIntoDay()) * (Double(settingsObj.manualActive) / 1440))
                }
            }
            
            if remainingFromAvg < 0 {
                return 0
            } else {
                if wasEstimate == false {
                    return weightActiveProjection(input: remainingFromAvg, style: nil, timeInput: nil)
                } else {
                    return Int(Double(1440 - minutesIntoDay()) * (Double(settingsObj.manualActive) / 1440))
                }
            }
        }
    }
    
    func getMoveGoal() async -> Int {
        let calendar = NSCalendar.current
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.calendar = calendar
        
        do {
            let activitySummaries: [HKActivitySummary] = try await withCheckedThrowingContinuation { continuation in
                let predicate = HKQuery.predicateForActivitySummary(with: startDateComponents)
                let query = HKActivitySummaryQuery(predicate: predicate) { (query, summariesOrNil, errorOrNil) -> Void in
                    if let errorOrNil {
                        continuation.resume(throwing: errorOrNil)
                        return
                    }
                    continuation.resume(returning: summariesOrNil!)
                }
                healthStore.execute(query)
            }
            guard let firstSummary = activitySummaries.first else {
                // Use a fallback value or throw an error.
                return 0
            }
            
            return Int(firstSummary.activeEnergyBurnedGoal.doubleValue(for: HKUnit.kilocalorie()))
        } catch {
            return 0
        }
    }
    
    func addCalories(calories: Int, narrative: String?, date: Date, meal: UUID) async {
        var dateOfEntry: Date
        var narrativeToLog: String
        
        dateOfEntry = date
        
        var didHK = Bool()
        var hkUUID: UUID = UUID()
        if settingsObj.manualMode != true {
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
        }
        if (narrative != "") && (narrative != nil) {
            narrativeToLog = narrative!
        } else {
            narrativeToLog = "Quick calories"
        }
        
        if didHK == true {
            let newCalorieObj: CalorieEntry = CalorieEntry(date: dateOfEntry, calories: calories, narrative: narrativeToLog, mealUUID: meal, isInHK: true, healthKitUUID: hkUUID)
            self.calorieModel.insertNewCals(object: newCalorieObj)
        } else {
            let newCalorieObj: CalorieEntry = CalorieEntry(date: dateOfEntry, calories: calories, narrative: narrativeToLog, mealUUID: meal, isInHK: false, healthKitUUID: nil)
            //await... removed
            self.calorieModel.insertNewCals(object: newCalorieObj)
        }
        
        self.lastUpdateRequestSource = "Addition of new calories"
        self.isBackgroundPing = false
        self.dataUpdated = true
    }
    
    func setUpObserverQueries(settingsObj: UserSettings) async {
        let activeQuery = HKObserverQuery(sampleType: activeQuantityType, predicate: observerPredicate){ (query, completionHandler, errorOrNil) in
            if errorOrNil != nil {
                // Properly handle the error.
                return
            }
            Task {
                self.lastUpdateRequestSource = "Active observer query"
                self.isBackgroundPing = true
                self.dataUpdated = true
            }
        }
        let basalQuery = HKObserverQuery(sampleType: basalQuantityType, predicate: observerPredicate){ (query, completionHandler, errorOrNil) in
            if errorOrNil != nil {
                // Properly handle the error.
                return
            }
            Task {
                self.isBackgroundPing = true
                self.lastUpdateRequestSource = "Basal observer query"
                self.dataUpdated = true
            }
        }
        
        let eatenQuery = HKObserverQuery(sampleType: eatenQuantityType, predicate: observerPredicate){ (query, completionHandler, errorOrNil) in
            if errorOrNil != nil {
                return
            }
            Task {
                self.isBackgroundPing = true
                self.lastUpdateRequestSource = "Eaten observer query"
                self.dataUpdated = true
            }
        }
       
        healthStore.execute(activeQuery)
        healthStore.execute(basalQuery)
        healthStore.execute(eatenQuery)
    }
    
    func produceTodayObject() async -> TodayLump {
        print("Update requested by: " + self.lastUpdateRequestSource)
        self.updateInProgress = true
        let todayStart = getStartOfDay(date: Date())
        let todayEnd = getMidnightOnDayAfter(date: todayStart)
        
        let newLump = TodayLump()
        
        let eatenCalories = await self.pullEatenCalories(startDate: todayStart, endDate: todayEnd)
        newLump.eatenCalories = eatenCalories.total
        newLump.foodList = await self.getCalorieEntries(date: todayStart)
        newLump.healthKitCalories = eatenCalories.hk
        newLump.mealList = await self.calorieModel.cleansedMealList(data: newLump.foodList)
    
        newLump.desiredDeficit = settingsObj.desiredDeficit
        newLump.projectedBasal = await self.getProjBasalCalories()
        newLump.projectedActive = await self.getProjActiveCalories()
        
        if settingsObj.manualMode == true {
            newLump.basalEstimated = true
            newLump.activeEstimated = true
            newLump.basalCalories = settingsObj.manualBMR - newLump.projectedBasal
            newLump.activeCalories = settingsObj.manualActive - newLump.projectedActive
        } else {
            let recBasalCalories = await self.pullCalorieTotalTodayFromHK(type: basalQuantityType)
            let recActiveCalories = await self.pullCalorieTotalTodayFromHK(type: activeQuantityType)
            if recBasalCalories != 0 {
                newLump.basalCalories = recBasalCalories
            } else {
                newLump.basalEstimated = true
                newLump.basalCalories = settingsObj.manualBMR - newLump.projectedBasal
            }
            if recActiveCalories != 0 {
                newLump.activeCalories = recActiveCalories
            } else {
                newLump.activeEstimated = true
                newLump.activeCalories = settingsObj.manualActive - newLump.projectedActive
            }
        }
        self.isBackgroundPing = false
        self.dataUpdated = false
        self.updateInProgress = false
        return newLump
    }
    
    func produceLumpForWatch(deficit: Int, manBMR: Int, manAct: Int) async -> TodayLump {
        print("Update requested by: " + self.lastUpdateRequestSource)
        self.updateInProgress = true
        let todayStart = getStartOfDay(date: Date())
        let todayEnd = getMidnightOnDayAfter(date: todayStart)
        
        let newLump = TodayLump()
        let eatenCalories = await self.pullEatenCalories(startDate: todayStart, endDate: todayEnd)
        newLump.eatenCalories = eatenCalories.total
        newLump.foodList = await self.getCalorieEntries(date: todayStart)
        newLump.healthKitCalories = eatenCalories.hk
        newLump.mealList = await self.calorieModel.cleansedMealList(data: newLump.foodList)
    
        newLump.desiredDeficit = settingsObj.desiredDeficit
        newLump.projectedBasal = await self.getProjBasalCalories()
        newLump.projectedActive = await self.getProjActiveCalories()
        
        if settingsObj.manualMode == true {
            newLump.basalEstimated = true
            newLump.activeEstimated = true
            newLump.basalCalories = settingsObj.manualBMR - newLump.projectedBasal
            newLump.activeCalories = settingsObj.manualActive - newLump.projectedActive
        } else {
            let recBasalCalories = await self.pullCalorieTotalTodayFromHK(type: basalQuantityType)
            let recActiveCalories = await self.pullCalorieTotalTodayFromHK(type: activeQuantityType)
            if recBasalCalories != 0 {
                newLump.basalCalories = recBasalCalories
            } else {
                newLump.basalEstimated = true
                newLump.basalCalories = settingsObj.manualBMR - newLump.projectedBasal
            }
            if recActiveCalories != 0 {
                newLump.activeCalories = recActiveCalories
            } else {
                newLump.activeEstimated = true
                if settingsObj.useFitnessGoal != true {
                    newLump.activeCalories = settingsObj.manualActive - newLump.projectedActive
                } else {
                    newLump.activeCalories = 0
                }
            }
        }
        self.isBackgroundPing = false
        self.dataUpdated = false
        self.updateInProgress = false
        return newLump
    }
}


