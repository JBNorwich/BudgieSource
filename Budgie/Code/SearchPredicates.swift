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

///HKQuantityType for water
let waterQuantityType = HKQuantityType(.dietaryWater)

let fitnessGoalType = HKSampleType.activitySummaryType()

let weightSampleType = HKQuantityType(.bodyMass)

let fitnessGoalSet: Set = [fitnessGoalType]

let writeTypes: Set = [
    eatenQuantityType,
    waterQuantityType,
    weightSampleType
]

let readTypes: Set = [
    eatenQuantityType,
    basalQuantityType,
    activeQuantityType,
    waterQuantityType,
    fitnessGoalType,
    weightSampleType
]


