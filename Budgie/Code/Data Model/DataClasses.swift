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
import SwiftUI
import Combine
#if !os(macOS)
import HealthKit
#endif

class TodayLump: ObservableObject {
    // Variables that need to be updated upon creation
    @Published var activeCalories: Int = 0
    @Published var basalCalories: Int = 0
    @Published var eatenCalories: Int = 0
    @Published var projectedActive: Int = 0
    @Published var projectedBasal: Int = 0
    @Published var waterToday: Int = 0
    @Published var weightToday: Double = 0
    @Published var weightYesterday: Double = 0
    @Published var lastWeightDate: Date? = nil
    @Published var prevWeightDate: Date? = nil
    @Published var averageDeficit: Int = 0
    @Published var lastWeekAvgWeight: Double = 0
    @Published var prevWeekAvgWeight: Double = 0
    @Published var foodDaysLoggedFortnight: Int = 0
    
    #if !os(macOS)
    @Published var activitySummary: HKActivitySummary = HKActivitySummary()
    #endif
    
    @Published private(set) var totalBudget: Int = 1200
    @Published private(set) var budgetAtCap: Bool = false
    @Published private(set) var budgetAtMin: Bool = false
    
    // food data
    /// A list of Meal()s in the database that don't include any that don't have food logged today.
    @Published var cleansedMealList: [Meal] = []
    /// A list of all Meal()s in the database, whether they've got food in them or not.
    @Published var allMeals: [Meal] = []
    /// The total calories for each meal that has calories in it.
    @Published var mealTotalList: [UUID:Int] = [:]
    @Published var foodList: [CalorieEntry] = []
    @Published var healthKitCalories: Int = 0
    
    // flags for estimation of data
    @Published var basalEstimated: Bool = false
    @Published var activeEstimated: Bool = false
    
    // signals re. data updates
    @Published var updateInProgress: Bool = false
    @Published var updateQueued: Bool = false
    @Published var lastUpdate: Date = Date()
    
    /// Whether a request that queued behind an in-flight update wanted to publish the snapshot. OR-combined so a foreground publish isn't lost when it queues behind a background pass.
    var queuedPublishSnapshot: Bool = false
    
    func recalculateBudget() {
        let uncapped = totalProjCalories - settingsObj.desiredDeficit
        var budget = max(uncapped, 1200)
        let atCap = settingsObj.capBudget && budget > settingsObj.capBudgetCals
        if atCap { budget = max(settingsObj.capBudgetCals, 1200) }
        // Only flag the minimum when the 1,200 floor actually kicked in — not when the
        // budget legitimately works out at exactly 1,200.
        let atMin = uncapped < 1200 || (atCap && settingsObj.capBudgetCals < 1200)

        totalBudget = budget
        budgetAtCap = atCap
        budgetAtMin = atMin
    }
    
    /// The "real" budget that would be calculated if the budget was not capped. Only relevant if the user has turned on capping; otherwise this will just return whatever the budget is.
    var realBudget: Int {
        return max(totalProjCalories - settingsObj.desiredDeficit, 1200)
    }
    
    /// The ledger adjustment applied because of the cap: capBudgetCals minus the uncapped budget, so it is NEGATIVE while the cap is active. NewDataView displays it as a deduction row, like the target deficit.
    var budgetOverCap: Int {
        return settingsObj.capBudgetCals - self.realBudget
    }
    
    /// The total amount remaining to eat from the user's budget.
    var totalBudgetRem: Int {
        return self.totalBudget - self.eatenCalories
    }
    
    /// The amount that the user can eat now, as weighted against their last meal time. Not meaningful in allocated budget mode, so in that mode, will return the user's remaining budget.
    var canEatNow: Int {
        guard self.totalBudget != 0 else { return 0 }
        // With meal allocations on, pacing is handled per-meal, so the blob shows the
        // plain remaining daily budget rather than the time-weighted figure — keeping it
        // consistent with, and never systematically below, the individual meal targets.
        if settingsObj.useMealAllocations {
            return self.totalBudgetRem
        }
        return weightCanEatNow(input: self.totalBudget) - self.eatenCalories
    }
    
    var totalProjCalories: Int {
        return self.activeCalories + self.basalCalories + self.projectedActive + self.projectedBasal
    }
    
    /// The percentage of the user's calorie budget that they have eaten.
    var progressToday: Double {
        if self.totalBudget != 0 {
            return (Double(self.eatenCalories) / Double(self.totalBudget))
        } else {
            return 0
        }
    }
    
    /// The user's "target" calories - how much of their budget, in total, the app thinks the user can eat while keeping some aside for their final meal.
    /// With meal allocations on, pacing is per-meal rather than by clock, so the target is simply the whole day's budget.
    var currentTarget: Int {
        if settingsObj.useMealAllocations {
            return self.totalBudget
        }
        return weightCanEatNow(input: self.totalBudget)
    }
    
    var progressAgainstTarget: Double {
        var returnVal: Double = 0
        if self.currentTarget != 0 {
            returnVal = Double(self.eatenCalories) / Double(self.currentTarget)
        }
        if returnVal > 2 {
            returnVal = 2
        } else if returnVal < 0 {
            returnVal = 0
        }
        return returnVal
    }
    
    var gaugeNumber: Int {
        if self.progressAgainstTarget != 0 {
            return Int(self.progressAgainstTarget * 100) - 100
        } else {
            return 0
        }
    }
    
    var calsOutNow: Int {
        return self.activeCalories + self.basalCalories
    }
    
    var waterGoalDone: Double {
        let done = Double(self.waterToday) / Double(self.effectiveWaterGoal)

        if done > 1 {
            return 1
        } else if done < 0 {
            return 0
        } else {
            return done
        }
    }
    
    var waterGoalRem: Int {
        let left = self.effectiveWaterGoal - self.waterToday
        if left < 0 {
            return 0
        } else {
            return left
        }
    }
    
    // WEIGHT RELATED CALCULATED VARIABLES

    /// A smoothed "current weight": the trailing weekly average when available, else the latest reading.
    /// Used for trend analysis so day-to-day scale noise doesn't make them jump.
    var currentWeight: Double {
        lastWeekAvgWeight != 0 ? lastWeekAvgWeight : weightToday
    }

    /// The amount of weight (kg) the user has to go to meet their goal.
    var weightToGo: Double {
        guard settingsObj.weightGoal != 0, weightToday != 0 else { return 0 }
        if weightGoalMet { return 0 }
        let remaining = settingsObj.surplusMode
            ? settingsObj.weightGoal - weightToday
            : weightToday - settingsObj.weightGoal
        return max(remaining, 0)
    }

    /// The change (kg) since the user's previous weigh-in (positive = down). Not necessarily one day.
    var changeSinceLastReading: Double {
        return self.weightYesterday - self.weightToday
    }

    /// Progress from start weight toward goal, 0 (just started) → 1 (met).
    var weightGoalProgress: Double {
        guard settingsObj.weightGoal != 0, settingsObj.startWeight != 0, weightToday != 0 else { return 0 }
        if weightGoalMet { return 1 }
        let total = settingsObj.surplusMode
            ? settingsObj.weightGoal - settingsObj.startWeight
            : settingsObj.startWeight - settingsObj.weightGoal
        let done = settingsObj.surplusMode
            ? weightToday - settingsObj.startWeight
            : settingsObj.startWeight - weightToday
        guard total > 0 else { return 0 }
        return min(max(done / total, 0), 1)
    }

    /// Whether the user has reached their weight goal, respecting goal direction.
    var weightGoalMet: Bool {
        guard settingsObj.weightGoal != 0, weightToday != 0 else { return false }
        return settingsObj.surplusMode
            ? weightToday >= settingsObj.weightGoal
            : weightToday <= settingsObj.weightGoal
    }

    /// The gauge value: how much of the journey is left (1 at start → 0 at goal).
    var weightGoalRemaining: Double { 1 - weightGoalProgress }

    /// Weight change between the previous week's average and the most recent week's average (positive = down).
    var weightTrend: Double {
        return self.prevWeekAvgWeight - self.lastWeekAvgWeight
    }

    /// Expected weekly weight change from the recorded average deficit (kg), unrounded — for maths.
    private var expectedWeeklyChangeExact: Double {
        return Double(self.averageDeficit * 7) / 7700
    }

    /// Expected weekly weight loss at the recorded deficit, rounded for display.
    var expectedWeightLossAtRealDeficit: Double {
        return roundDoubleWeight(input: expectedWeeklyChangeExact)
    }

    /// How actual weight change compares to expectation. >1 better than expected, <1 worse.
    /// nil when there's no meaningful expectation to compare against (deficit ≈ 0).
    var performanceAgainstWeightTrend: Double? {
        // Both weekly averages must exist for the trend to mean anything.
        guard lastWeekAvgWeight != 0, prevWeekAvgWeight != 0 else { return nil }
        let expected = expectedWeeklyChangeExact
        guard abs(expected) > 0.001 else { return nil }
        return self.weightTrend / expected
    }

    /// Measured daily energy imbalance in the direction of the user's goal: a deficit when
    /// losing, a surplus when gaining. Positive means they're moving toward their goal.
    private var measuredGoalRate: Int {
        settingsObj.surplusMode ? -averageDeficit : averageDeficit
    }

    /// The rate the user's actual progress implies, adjusting the measured rate by performance.
    var realDeficit: Int {
        guard measuredGoalRate > 0, let performance = performanceAgainstWeightTrend else { return 0 }
        let doubleCalc = Double(measuredGoalRate) * performance
        guard doubleCalc.isFinite, !doubleCalc.isNaN else { return 0 }
        return Int(doubleCalc)
    }

    /// Whether the user has logged food on enough of the last 14 days for target-tracking figures to be meaningful.
    var consistentlyLoggedFood: Bool {
        foodDaysLoggedFortnight >= 12
    }

    /// The daily rate (cal/day, always positive, in the goal direction) to base "time to goal"
    /// projections on. Uses the user's measured rate once they've logged food consistently
    /// enough for it to be meaningful; otherwise falls back to their planned target.
    var goalProjectionDeficit: Int {
        guard consistentlyLoggedFood, measuredGoalRate > 0 else {
            return abs(settingsObj.desiredDeficit)
        }
        return realDeficit > 0 ? realDeficit : measuredGoalRate
    }

    /// Whether there's a meaningful "time to goal" estimate to show — i.e. we're not moving
    /// the wrong way (surplus when losing, deficit when gaining) and the projection is positive.
    var hasGoalTimeEstimate: Bool {
        if consistentlyLoggedFood && measuredGoalRate <= 0 { return false }
        return goalProjectionDeficit > 0
    }
    
    /// Per-meal calorie targets when allocations are enabled. Non-Snacks meals get round(percent% × budget); Snacks/Other absorbs the remainder and any rounding.
    /// Returns an empty dictionary when the feature is off.
    var mealAllocationTargets: [UUID: Int] {
        guard settingsObj.useMealAllocations else { return [:] }
        let budget = self.totalBudget
        let snacksUUID = settingsObj.snacksUUID
        var targets: [UUID: Int] = [:]
        var allocated = 0
        for meal in allMeals where meal.mealUUID != snacksUUID {
            let t = Int((meal.budgetPercent / 100 * Double(budget)).rounded())
            targets[meal.mealUUID] = t
            allocated += t
        }
        if let snacksUUID {
            targets[snacksUUID] = max(budget - allocated, 0)
        }
        return targets
    }
    
    /// The user's water goal, topped up by 1 ml per active calorie burned today when
    /// the "increase goal with activity" setting is on.
    var effectiveWaterGoal: Int {
        let base = settingsObj.waterGoal
        return settingsObj.waterFromActivity ? base + max(activeCalories, 0) : base
    }
    
    /// Applies a budget computed on another device (the iPhone). Used on platforms without HealthKit, where `recalculateBudget()` can't run because there's no activity data.
    func applyBudgetSnapshot(budget: Int, atCap: Bool, atMin: Bool) {
        totalBudget = budget
        budgetAtCap = atCap
        budgetAtMin = atMin
    }
}

struct CalsPacket {
    var date: Date
    var cals: Int
}

/// Struct that holds an individual data point of weight.
struct WeightPoint: Identifiable {
    let id = UUID()
    let date: Date
    let kilos: Double
}
