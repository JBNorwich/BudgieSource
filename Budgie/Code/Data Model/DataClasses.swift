//
//  DataClasses.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 28/08/2024.
//

import Foundation
import SwiftUI
import HealthKit

class TodayLump: ObservableObject {
    // Variables that need to be updated upon creation
    @Published var activeCalories: Int = 0
    @Published var basalCalories: Int = 0
    @Published var eatenCalories: Int = 0
    @Published var desiredDeficit: Int = 0
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
    
    var lostInDay: Double {
        return self.weightYesterday - self.weightToday
    }
    
    // return the percentage of the weight goal that is left to achieve
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
    
    // returns weight lost as difference between last week's average weight, and the weight today
    var weightTrend: Double {
        return self.lastWeekAvgWeight - self.weightToday
    }
    
    // return the days as an int that it will take to get to next weight goal, based on a real average deficit adjusted for real performance
    var daysToWeightGoal: Int {
        let days = getDaysToLose(weight: self.weightToGo, deficit: self.averageDeficit)
        return days
    }

    var daysToGoalAtPlanned: Int {
        return getDaysToLose(weight: self.weightToGo, deficit: settingsObj.desiredDeficit)
    }
    
    // difference between days to weight goal at current trend and days as calculated from desired deficit.
    // positive: taking longer than plannedß
    // negative: taking less time than planned
    var diffDays: Int {
        return daysToWeightGoal - daysToGoalAtPlanned
    }
    
    // negative = deficit not big enough
    // positive = deficit bigger than desired
    var diffBetweenAvgDeficitandDesired: Int {
        return self.averageDeficit - settingsObj.desiredDeficit
    }
    
    // how much weight would be expected to be lost at current deficit. Positive figure
    var expectedWeightLossAtRealDeficit: Double {
        let totalDeficit = self.averageDeficit * 7
        let kilosExpected: Double = Double(totalDeficit) / 7700
        return roundDoubleWeight(input: kilosExpected)
    }
    
    // how expected weight loss measuresagainst the expected
    var performanceAgainstWeightTrend: Double {
        let expected = self.expectedWeightLossAtRealDeficit
        let actual = self.weightTrend
        // if result is > 1: weight loss above expectation
        // if result is < 1: weight loss below expectation
        let result = actual/expected
        return result
    }
    
    var realDeficit: Int {
        if self.averageDeficit <= 0 {
            return 0
        } else {
            let doubleCalc = Double(self.averageDeficit) * self.performanceAgainstWeightTrend
            print ("Adjusted from \(self.averageDeficit) to \(Int(doubleCalc).formatted())")
            return Int(doubleCalc)
        }
    }
    
    // Calculating functions
    var totalBudget: Int {
        var budget: Int = 0
        if self.totalProjCalories - self.desiredDeficit > -1 {
            budget = self.totalProjCalories - self.desiredDeficit
        } else {
            budget = 0
        }
        
        if settingsObj.capBudget == true && budget > settingsObj.capBudgetCals {
            budget = settingsObj.capBudgetCals
            self.budgetAtCap = true
        } else {
            self.budgetAtCap = false
        }
        
        if budget < 1200 {
            budget = 1200
            self.budgetAtMin = true
        } else {
            self.budgetAtMin = false
        }
        
        return budget
    }
    
    var realBudget: Int {
        var budget: Int = 0
        
        if self.totalProjCalories - self.desiredDeficit > -1 {
            budget = self.totalProjCalories - self.desiredDeficit
        } else {
            budget = 0
        }
        
        if budget < 1200 {
            budget = 1200
        }
        
        return budget
    }
    
    var budgetOverCap: Int {
        return settingsObj.capBudgetCals - self.realBudget
    }
    
    var progressTodayInt: Int {
        var progress = self.progressTodayAsWholePercent
        if progress > 100 { progress = 100 }
        return Int(progress)
    }
    
    var totalBudgetRem: Int {
        return self.totalBudget - self.eatenCalories
    }
    
    var totalCaloriesOut: Int {
        return self.activeCalories + self.basalCalories
    }
    
    var leftToEat: Int {
        if self.totalBudget != 0 {
            return weightLeftToEat(input: self.totalBudget) - self.eatenCalories
        } else {
            return 0
        }
    }
    
    var totalProjCalories: Int {
        return self.activeCalories + self.basalCalories + self.projectedActive + self.projectedBasal
    }
    
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
        return weightLeftToEat(input: self.totalBudget)
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
        if self.leftToEat < -49
        {
            switch settingsObj.surplusMode {
            case true: returnColor = .green
            case false : returnColor = .red
            }
        } else if self.leftToEat < 50 {
            switch settingsObj.surplusMode {
            case true: returnColor = .red
            case false: returnColor = .green
            }
        }
        return returnColor
    }
    
    var normalisedLTE: String {
        var valueReturned: Int = 0
        if self.leftToEat < 0
        {
            valueReturned = -self.leftToEat
        } else {
            valueReturned = self.leftToEat
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
