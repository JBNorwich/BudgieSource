//
//  DemisedFuncs.swift
//  Budgie
//
//  Created by Joe Baldwin on 26/08/2024.
//

//import Foundation
////FROM HEALTHDATA CLASS
///

//    func getAverageDailyActiveCalories() async -> Int {
//        let calendar = Calendar.current
//        var calories: Double = 0
//        var calsToAdd: Double = 0
//        let activeCalsType = HKQuantityType(.activeEnergyBurned)
//        let descriptor = HKSampleQueryDescriptor(predicates:[.quantitySample(type: activeCalsType, predicate: prevWeekPredicate)], sortDescriptors: [])
//        var earliestSample = Date()
//        var latestSample = Date()
//        var daysInSample = Int()
//        do {
//            let results = try await descriptor.result(for: healthStore)
//            for result in results {
//                calories += result.quantity.doubleValue(for: HKUnit.kilocalorie())
//                if result.endDate > latestSample
//                { latestSample = result.startDate }
//                if result.startDate < earliestSample
//                { earliestSample = result.startDate }
//            }
//            daysInSample = calendar.numberOfDaysBetween(earliestSample, and: latestSample)
//        } catch {
//            // error handling
//        }
//
//
//        if daysInSample != 0 { daysInSample = daysInSample - 1 }
//
//        if daysInSample < 7 {
//            let daysToAdd = 7 - daysInSample
//            let manAct = Double(settingsObj.manualActive)
//            calsToAdd = Double(daysToAdd) * manAct
//            daysInSample = 7
//        }
//
//        calories = (calsToAdd + calories) / Double(daysInSample)
//
//        return Int(calories)
//    }
//
//    func getAverageDailyBasalCalories() async -> Int {
//        let calendar = Calendar.current
//        var calories: Double = 0
//        var calsToAdd: Double = 0
//        let descriptor = HKSampleQueryDescriptor(predicates:[.quantitySample(type: basalQuantityType, predicate: prevWeekPredicate)], sortDescriptors: [])
//        var earliestSample = Date()
//        var latestSample = Date()
//        var daysInSample = Int()
//        do {
//            let results = try await descriptor.result(for: healthStore)
//            for result in results {
//                calories += result.quantity.doubleValue(for: HKUnit.kilocalorie())
//                if result.endDate > latestSample
//                { latestSample = result.startDate }
//                if result.startDate < earliestSample
//                { earliestSample = result.startDate }
//            }
//            daysInSample = calendar.numberOfDaysBetween(earliestSample, and: latestSample)
//        } catch {
//            // error handling
//        }
//
//        if daysInSample != 0 { daysInSample = daysInSample - 1 }
//
//        if daysInSample < 7 {
//            let daysToAdd = 7 - daysInSample
//            let manBMR = Double(settingsObj.manualBMR)
//            calsToAdd = Double(daysToAdd) * manBMR
//            daysInSample = 7
//        }
//
//        calories = (calsToAdd + calories) / Double(daysInSample)
//
//        return Int(calories)
//    }

//func weightForUncertainty(input: Int) -> Int {
//    let uncertaintyWeight = 1 - getWeightingFactor()
//    return Int(Double(input) * uncertaintyWeight)
//}


//func rationByRemainingTime(input: Int) -> Int {
//    let minsIntoDay = minutesIntoDay()
//    if minsIntoDay == 0 {
//        return 0
//    } else {
//        let percentOfDayToCome: Double = 1 - (Double(minutesIntoDay()) / 1440)
//        return Int(percentOfDayToCome * Double(input))
//    }
//}
