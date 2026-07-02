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
import HealthKit

class TodayLump: ObservableObject {
    // Variables that need to be updated upon creation
    @Published var activeCalories: Int = 0
    @Published var basalCalories: Int = 0
    @Published var eatenCalories: Int = 0
    @Published var projectedActive: Int = 0
    @Published var projectedBasal: Int = 0
    @Published var waterToday: Int = 0
    @Published var activitySummary: HKActivitySummary = HKActivitySummary()
    @Published var weightToday: Double = 0
    @Published var weightYesterday: Double = 0
    @Published var lastWeightDate: Date? = nil
    @Published var averageDeficit: Int = 0
    @Published var yesterdayDeficit: Int = 0
    @Published var lastWeekAvgWeight: Double = 0
    @Published var prevWeekAvgWeight: Double = 0
    @Published var foodDaysLoggedFortnight: Int = 0
    
    @Published private(set) var totalBudget: Int = 1200
    @Published private(set) var budgetAtCap: Bool = false
    @Published private(set) var budgetAtMin: Bool = false
    
    // food data
    @Published var mealList: [Meal] = []
    @Published var mealTotalList: [UUID:Int] = [:]
    var mealsWithUUIDs: [String:UUID] = [:]
    @Published var foodList: [CalorieEntry] = []
    @Published var healthKitCalories: Int = 0
    
    // flags for estimation of data
    @Published var basalEstimated: Bool = false
    @Published var activeEstimated: Bool = false
    
    // signals re. data updates
    @Published var updateInProgress: Bool = false
    @Published var updateQueued: Bool = false
    @Published var lastUpdate: Date = Date()
    
    func recalculateBudget() {
        var budget = totalProjCalories - settingsObj.desiredDeficit > -1
            ? totalProjCalories - settingsObj.desiredDeficit
            : 1200
        let atCap = settingsObj.capBudget && budget > settingsObj.capBudgetCals
        if atCap {
            budget = settingsObj.capBudgetCals
        }
        
        let atMin = budget < 1200
        if atMin {
            budget = 1200
        }
        
        totalBudget = budget
        budgetAtCap = atCap
        budgetAtMin = atMin
    }
    
    /// The "real" budget that would be calculated if the budget was not capped. Only relevant if the user has turned on capping; otherwise this will just return whatever the budget is.
    var realBudget: Int {
        var budget: Int
        
        if self.totalProjCalories - settingsObj.desiredDeficit > -1 {
            budget = self.totalProjCalories - settingsObj.desiredDeficit
        } else {
            budget = 0
        }
        
        if budget < 1200 {
            budget = 1200
        }
        
        return budget
    }
    
    /// The amount that has been knocked off the user's budget because of the cap.
    var budgetOverCap: Int {
        return settingsObj.capBudgetCals - self.realBudget
    }
    
    /// The total amount remaining to eat from the user's budget.
    var totalBudgetRem: Int {
        return self.totalBudget - self.eatenCalories
    }
    
    /// The amount that the user can eat now, as weighted against their last meal time.
    var canEatNow: Int {
        if self.totalBudget != 0 {
            return weightCanEatNow(input: self.totalBudget) - self.eatenCalories
        } else {
            return 0
        }
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
    
    var progressTodayAsWholePercent: Double {
        return progressToday * 100
    }
    
    var currentTarget: Int {
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
    
    var progressAgainstTime: Double {
        //0.74 / 0.666
        let value = self.progressToday / getPercentOfDayDone()
        return value
    }
    
    var budgetDiffByTime: Int {
        // 0.11 * (0.666 * 2454)
        let result = (self.progressAgainstTime - 1) * (getPercentOfDayDone() * Double(self.totalBudget))
        return Int(result)
    }
    
    var gaugeNumber: Int {
        if self.progressAgainstTarget != 0 {
            return Int(self.progressAgainstTarget * 100) - 100
        } else {
            return 0
        }
    }
    
    var meterNumber: Double {
        let budg = Double(weightForCertainty(input: self.totalBudget))
        let eaten = Double(self.eatenCalories)
        let weighted = eaten/budg
        
        return weighted
    }
    
    func getPathColour() -> Color
    {
        let reallyGoodColor = (Color.blue)
        let goodColour = Color(.green)
        let okColour = Color(.yellow)
        let badColour = Color(.red)
        
        let diff = self.progressAgainstTarget
        
        if diff < 0.25 {
            return reallyGoodColor
        } else if diff < 1.05 {
            return goodColour
        } else if diff < 1.20 {
            if (diff - 1) * Double(self.totalBudget) < Double(self.projectedBasal) {
                return goodColour
            } else {
                return okColour
            }
        } else {
            return badColour
        }
    }
    
    func getBlobColour() -> Color
    {
        var returnColor: Color = .teal
        if self.canEatNow < -49
        {
            switch settingsObj.surplusMode {
            case true: returnColor = .green
            case false : returnColor = .red
            }
        } else if self.canEatNow < 50 {
            switch settingsObj.surplusMode {
            case true: returnColor = .red
            case false: returnColor = .green
            }
        }
        return returnColor
    }
    
    var normalisedLTE: String {
        var valueReturned: Int = 0
        if self.canEatNow < 0
        {
            valueReturned = -self.canEatNow
        } else {
            valueReturned = self.canEatNow
        }
        return valueReturned.formatted()
    }
    
    var calsOutNow: Int {
        return self.activeCalories + self.basalCalories
    }
    
    var waterGoalDone: Double {
        let done = Double(self.waterToday) / Double(settingsObj.waterGoal)
        if done > 1 {
            return 1
        } else if done < 0 {
            return 0
        } else {
            return done
        }
    }
    
    var waterGoalRem: Int {
        let left = settingsObj.waterGoal - self.waterToday
        if left < 0 {
            return 0
        } else {
            return left
        }
    }
    
    // WEIGHT RELATED CALCULATED VARIABLES
    /// The amount of weight that the user has to go, as a Double reflecting kilograms, in order to meet their goal.
    var weightToGo: Double {
        guard settingsObj.weightGoal != 0, self.weightToday != 0 else { return 0 }
        if weightGoalMet { return 0 }
        let remaining = settingsObj.surplusMode
            ? settingsObj.weightGoal - self.weightToday
            : self.weightToday - settingsObj.weightGoal
        return max(remaining, 0)
    }
    
    /// The amount of weight that the user has lost, in kilograms as a Double.
    var lostInDay: Double {
        return self.weightYesterday - self.weightToday
    }
    
    /// Progress from start weight toward goal, 0 (just started) → 1 (met).
    var weightGoalProgress: Double {
        guard settingsObj.weightGoal != 0, settingsObj.startWeight != 0, self.weightToday != 0 else { return 0 }
        if weightGoalMet { return 1 }
        let total = settingsObj.surplusMode
            ? settingsObj.weightGoal - settingsObj.startWeight
            : settingsObj.startWeight - settingsObj.weightGoal
        let done = settingsObj.surplusMode
            ? self.weightToday - settingsObj.startWeight
            : settingsObj.startWeight - self.weightToday
        guard total > 0 else { return 0 }
        return min(max(done / total, 0), 1)
    }

    /// Whether the user has reached their weight goal, respecting goal direction.
    var weightGoalMet: Bool {
        guard settingsObj.weightGoal != 0, self.weightToday != 0 else { return false }
        return settingsObj.surplusMode
            ? self.weightToday >= settingsObj.weightGoal      // gaining
            : self.weightToday <= settingsObj.weightGoal      // losing
    }
    
    /// The gauge value: how much of the journey is left (1 at start → 0 at goal).
    var weightGoalRemaining: Double { 1 - weightGoalProgress }
    
    /// The user's weight lost as the difference between last week's average weight, and the past week's average weight, in kilograms.
    var weightTrend: Double {
        return self.prevWeekAvgWeight - self.lastWeekAvgWeight
    }
    
    /// The number of days (as an Int) that it will take the user to get to their next weight goal, based on a real average deficit adjusted for real performance
    var daysToWeightGoal: Int {
        let days = getDaysToLose(weight: self.weightToGo, deficit: self.averageDeficit)
        return days
    }

    /// The number of days (as an Int) that it would take the user to get to their next weight goal, as a rough calculation based on their expressed desired deficit.
    var daysToGoalAtPlanned: Int {
        return getDaysToLose(weight: self.weightToGo, deficit: settingsObj.desiredDeficit)
    }
    
    /// The difference between the days to the user's weight goal at current trend, and days as calculated from their desired deficit. If positive, it is taking the user longer than planned (i.e. more days to goal); if negative, it is taking the user less time than planned (i.e. fewer days to goal.)
    var diffDays: Int {
        return daysToWeightGoal - daysToGoalAtPlanned
    }
    
    /// The difference between the user's average caloric deficit, and the desired deficit they've set. If this is negative, their deficit is less than they planned; if positive, the opposite.
    var diffBetweenAvgDeficitandDesired: Int {
        return self.averageDeficit - settingsObj.desiredDeficit
    }
    
    /// How much weight would be expected to be lost at the users's current real deficit. If this is positive, the user is expected to lose weight; if negative, gain.
    var expectedWeightLossAtRealDeficit: Double {
        let totalDeficit = self.averageDeficit * 7
        let kilosExpected: Double = Double(totalDeficit) / 7700
        return roundDoubleWeight(input: kilosExpected)
    }
    
    /// How the user's weight loss (as recorded via HealthKit) is against what would be expected based on their deficits as recorded in Budgie Diet. If the result is above 1, the weight loss is above expectations; if the result is below 1, it's below what would be expected.
    var performanceAgainstWeightTrend: Double {
        let expected = self.expectedWeightLossAtRealDeficit
        let actual = self.weightTrend
        let result = actual/expected
        return result
    }
    
    /// What the user's "actual" caloric deficit is, based on their weight loss performance.
    var realDeficit: Int {
        if self.averageDeficit <= 0 {
            return 0
        } else {
            let doubleCalc = Double(self.averageDeficit) * self.performanceAgainstWeightTrend
            if doubleCalc.isFinite == true && doubleCalc.isNaN == false {
                return Int(doubleCalc)
            } else {
                return 0
            }
        }
    }
    
    /// Whether the user has logged food on enough of the last 14 days for target-tracking figures to be meaningful.
    var consistentlyLoggedFood: Bool {
        foodDaysLoggedFortnight >= 12
    }
}

struct calorieChartData: Identifiable {
    var id: UUID
    var date: Date
    var calsIn: Int
    var calsOut: Int
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
