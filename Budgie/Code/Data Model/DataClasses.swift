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
    
    var budgetAtCap: Bool = false
    var budgetAtMin: Bool = false
    var budgetNil: Bool = false
    
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
    @Published var lastUpdate: Date = Date()
    
    // CALCULATED BUDGET VARIABLES
    /// The user's calculated budget, taking into account their current and predicted caloric burn.
    var totalBudget: Int {
        var budget: Int
        
        // If the user's total caloric burn less their desired deficit is more than -1, return it. Otherwise, set the budget to the lower bound and flag it. (We'll clean this up later when we implement the hard bottom.)
        if self.totalProjCalories - settingsObj.desiredDeficit > -1 {
            budget = self.totalProjCalories - settingsObj.desiredDeficit
        } else {
            budgetNil = true
            budget = 1200
        }
        
        // Budget capping. If the user has turned on budget capping, and the calculated budget above is above the cap, set the budget to the cap and toggle the flag.
        if settingsObj.capBudget == true && budget > settingsObj.capBudgetCals {
            budget = settingsObj.capBudgetCals
            self.budgetAtCap = true
        } else {
            self.budgetAtCap = false
        }
        
        // Budget minimum to prevent the user from being given a budget that is unsustainably low, either deliberately or through a failure of HealthKit.
        if budget < 1200 {
            budget = 1200
            self.budgetAtMin = true
        } else {
            self.budgetAtMin = false
        }
        
        return budget
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
    
//    // Doesn't appear to be used by anything. Pointless. Why did I code this?
//    var progressTodayInt: Int {
//        var progress = self.progressTodayAsWholePercent
//        if progress > 100 { progress = 100 }
//        return Int(progress)
//    }
    
    /// The total amount remaining to eat from the user's budget.
    var totalBudgetRem: Int {
        return self.totalBudget - self.eatenCalories
    }

//      // Another variable I made that isn't read by anything. Yay!
//    var totalCaloriesOut: Int {
//        return self.activeCalories + self.basalCalories
//    }
    
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
        if settingsObj.weightGoal != 0 && self.weightToday != 0
        {
            if self.weightToday <= settingsObj.weightGoal {
                return 0
            } else {
                return weightToday - settingsObj.weightGoal
            }
        } else {
            return 0
        }
    }
    
    /// The amount of weight that the user has lost, in kilograms as a Double.
    var lostInDay: Double {
        return self.weightYesterday - self.weightToday
    }
    
    /// The percentage of the user's weight goal to go, against their start weight.
    var weightGoalLeft: Double {
        if settingsObj.weightGoal != 0 && settingsObj.startWeight != 0 && self.weightToday != 0 {
            let totalToLose: Double = settingsObj.startWeight - settingsObj.weightGoal
            let actLost: Double = settingsObj.startWeight - self.weightToday
            let percentLost: Double = actLost/totalToLose
            return 1 - percentLost
        } else {
            return 0
        }
    }
    
    /// The user's weight lost as the difference between last week's average weight, and the weight today, in kilograms.
    var weightTrend: Double {
        return self.lastWeekAvgWeight - self.weightToday
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

struct WeightPacket: Identifiable {
    var id: UUID
    var date: Date
    var weight: Double
    var deficit: Int
}
