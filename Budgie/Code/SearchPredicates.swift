//
//  SearchPredicates.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 26/08/2024.
//

import Foundation
import HealthKitUI

//PREDICATES FOR REUSE
/// Predicate that returns only data not logged by Budgie Diet.

let notBudgiePredicate = NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default()))


func getTodayPredicate() -> NSPredicate {
    let todayPredicate = HKQuery.predicateForSamples(withStart: getStartOfDay(date: Date()), end: getMidnightOnDayAfter(date: Date()), options: HKQueryOptions.strictEndDate)
    return todayPredicate
}

func getPrevWeekPredicate() -> NSPredicate {
    let prevWeekPredicate = HKQuery.predicateForSamples(withStart: getWeekBeforeDate(date: getStartOfDay(date: Date())), end: getStartOfDay(date: Date()), options: HKQueryOptions.strictEndDate)
    return prevWeekPredicate
}

/// Predicate that returns everything from 00:00 today until forever. Used for continuous fetching of calorie data.
let observerPredicate = HKQuery.predicateForSamples(withStart: getStartOfDay(date: Date()), end:.none)

/// Predicate that returns samples from today that were not logged by Budgie Diet.
func getNotBudgieTodayPredicate() -> NSCompoundPredicate
{
    let todayPredicate = getTodayPredicate()
    let notBudgieTodayPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,todayPredicate])
    return notBudgieTodayPredicate
}

//HKQUANTITYTYPES FOR REUSE

///HKQuantityType that represents resting energy.
let basalQuantityType = HKQuantityType(.basalEnergyBurned)

///HKQuantityType that represents active energy burned.
let activeQuantityType = HKQuantityType(.activeEnergyBurned)

///HKQuantityType that represents calories eaten.
let eatenQuantityType = HKQuantityType(.dietaryEnergyConsumed)

let fitnessGoalType = HKSampleType.activitySummaryType()

let fitnessGoalSet: Set = [fitnessGoalType]

let writeTypes: Set = [
    eatenQuantityType
]

let readTypes: Set = [
    eatenQuantityType,
    basalQuantityType,
    activeQuantityType
]


