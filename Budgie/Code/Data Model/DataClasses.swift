//
//  DataClasses.swift
//  Budgie
//
//  Created by Joe Baldwin on 28/08/2024.
//

import Foundation
import SwiftUI

class TodayLump: ObservableObject {
    // Variables that need to be updated upon creation
    var activeCalories: Int = 0
    var basalCalories: Int = 0
    var eatenCalories: Int = 0
    var desiredDeficit: Int = 0
    var projectedActive: Int = 0
    var projectedBasal: Int = 0
    
    // food data
    var mealList: [Meal] = []
    var foodList: [CalorieEntry] = []
    var healthKitCalories: Int = 0

    // flags for estimation of data
    var basalEstimated: Bool = false
    var activeEstimated: Bool = false
    var estimatedAverageActive: Bool = false
    
    // signals re. data updates
    var lastUpdate = Date()
    
    // Calculating functions
    var totalBudget: Int {
        if self.totalProjCalories - self.desiredDeficit > -1 {
            return self.totalProjCalories - self.desiredDeficit
        } else {
            return 0
        }
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
            return weightForCertainty(input: self.totalBudget) - self.eatenCalories
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
    
    var progressAgainstTime: Double {
        let value = self.progressToday / getPercentOfDayDone()
        return value
    }
    
    var budgetDiffByTime: Int {
        let result = (self.progressAgainstTime - 1) * (getPercentOfDayDone() * Double(self.totalBudget))
        return Int(result)
    }
    
    var gaugeNumber: Int {
        return Int(self.progressAgainstTime * 100) - 100
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
        
        let diff = self.progressAgainstTime
        
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


