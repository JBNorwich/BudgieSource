//
//  UserSettings.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 22/08/2024.
//

import Foundation
import SwiftUI
import SwiftData

class UserSettings {
    private let defaults = UserDefaults(suiteName: "group.JoeBaldwin.Budgie")
    
    init()
    {
        
    }
    
    var desiredDeficit: Int {
        get { return defaults?.value(forKey: "desiredDeficit") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "desiredDeficit")}
    }
        
    var isFirstRun: Bool {
        get { return defaults?.value(forKey: "firstRun") as? Bool ?? true }
        set { defaults?.set(newValue, forKey: "firstRun")}
    }
    
    var manualBMR: Int {
        get { return defaults?.value(forKey: "manualBMR") as? Int ?? 2000 }
        set { defaults?.set(newValue, forKey: "manualBMR")}
    }
    
    var manualActive: Int {
        get { return defaults?.value(forKey: "manualActive") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "manualActive")}
    }
    
    var manualMode: Bool {
        get { return defaults?.value(forKey: "manualMode") as? Bool ?? false}
        set { defaults?.set(newValue, forKey: "manualMode")}
    }
    
    var surplusMode: Bool {
        get { return defaults?.value(forKey: "surplusMode") as? Bool ?? false}
        set { defaults?.set(newValue, forKey: "surplusMode")}
    }
    
    var weight: Int {
        get { return defaults?.value(forKey: "weight") as? Int ?? 90 }
        set { defaults?.set(newValue, forKey: "weight")}
    }
    
    var height: Int {
        get { return defaults?.value(forKey: "height") as? Int ?? 175 }
        set { defaults?.set(newValue, forKey: "height")}
    }
    
    var birthYear: Int {
        get { return defaults?.value(forKey: "birthYear") as? Int ?? 2000 }
        set { defaults?.set(newValue, forKey: "birthYear")}
    }
    
    var impMetric: Int {
        get { return defaults?.value(forKey: "impMetric") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "impMetric")}
    }
    
    var userSex: Int {
        get { return defaults?.value(forKey: "userGender") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "userGender")}
    }
    
    var bmrMultiplier: Double {
        get { return defaults?.value(forKey: "bmrMultiplier") as? Double ?? 0.2 }
        set { defaults?.set(newValue, forKey: "userSex")}
    }
    
    var whalesEverywhere: Bool {
        get { return defaults?.value(forKey: "whalesEverywhere") as? Bool ?? false}
        set { defaults?.set(newValue, forKey: "whalesEverywhere")}
    }
    
    var healthLogging: Bool {
        get { return defaults?.value(forKey: "healthLogging") as? Bool ?? true}
        set { defaults?.set(newValue, forKey: "healthLogging")}
    }
    
    /// 0 is regular. -1 is forgiving. 1 is harsh. 2 is no projection at all.
    var weightingStyle: Int {
        get { return defaults?.value(forKey: "weightingStyle") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "weightingStyle")}
    }
    
    var hideTodayInDetail: Bool {
        get { return defaults?.value(forKey: "hideTodayInDetail") as? Bool ?? true }
        set { defaults?.set(newValue, forKey: "hideTodayInDetail")}
    }
    
    var shownExplainer: Bool {
        get { return defaults?.value(forKey: "shownExplainer") as? Bool ?? false }
        set { defaults?.set(newValue, forKey: "shownExplainer")}
    }
    
    var donated: Bool {
        get { return defaults?.value(forKey: "donated") as? Bool ?? true }
        set { defaults?.set(newValue, forKey: "donated")}
    }
    
    var differentWeights: Bool {
        get { return defaults?.value(forKey: "differentWeights") as? Bool ?? false }
        set { defaults?.set(newValue, forKey: "differentWeights")}
    }
    
    var monWeight: Int {
        get { return defaults?.value(forKey: "monWeight") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "monWeight")}
    }
    
    var tuesWeight: Int {
        get { return defaults?.value(forKey: "tuesWeight") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "tuesWeight")}
    }
    
    var wedsWeight: Int {
        get { return defaults?.value(forKey: "wedsWeight") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "wedsWeight")}
    }
    
    var thursWeight: Int {
        get { return defaults?.value(forKey: "thursWeight") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "thursWeight")}
    }
    
    var friWeight: Int {
        get { return defaults?.value(forKey: "friWeight") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "friWeight")}
    }
    
    var satWeight: Int {
        get { return defaults?.value(forKey: "satWeight") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "satWeight")}
    }
    
    var sunWeight: Int {
        get { return defaults?.value(forKey: "sunWeight") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "sunWeight")}
    }
    
    var useFitnessGoal: Bool {
        get { return defaults?.value(forKey: "useFitnessGoal") as? Bool ?? false }
        set { defaults?.set(newValue, forKey: "useFitnessGoal")}
    }
    
    var capBudget: Bool {
        get { return defaults?.value(forKey: "capBudget") as? Bool ?? false }
        set { defaults?.set(newValue, forKey: "capBudget")}
    }
    
    var capBudgetCals: Int {
        get { return defaults?.value(forKey: "capBudgetCals") as? Int ?? 2000 }
        set { defaults?.set(newValue, forKey: "capBudgetCals")}
    }
    
    var finalMealTime: Int {
        get { return defaults?.value(forKey: "finalMealTime") as? Int ?? 1080 }
        set { defaults?.set(newValue, forKey: "finalMealTime")}
    }
    
    var waterGoal: Int {
        get { return defaults?.value(forKey: "waterGoal") as? Int ?? 2000 }
        set { defaults?.set(newValue, forKey: "waterGoal")}
    }
    
    var weightGoal: Double {
        get { return defaults?.value(forKey: "weightGoal") as? Double ?? 0 }
        set { defaults?.set(newValue, forKey: "weightGoal") }
    }
    
    var startWeight: Double {
        get { return defaults?.value(forKey: "startWeight") as? Double ?? 0 }
        set { defaults?.set(newValue, forKey: "startWeight") }
    }
    
    func dumpToDict() -> [String:Any] {
        var dict: [String:Any] = [:]
        dict["surplusMode"] = self.surplusMode
        dict["desiredDeficit"] = self.desiredDeficit
        dict["manualBMR"] = self.manualBMR
        dict["manualActive"] = self.manualActive
        dict["weightingStyle"] = self.weightingStyle
        dict["manualMode"] = self.manualMode
        dict["differentWeights"] = self.differentWeights
        dict["monWeight"] = self.monWeight
        dict["tuesWeight"] = self.tuesWeight
        dict["wedsWeight"] = self.wedsWeight
        dict["thursWeight"] = self.thursWeight
        dict["friWeight"] = self.friWeight
        dict["satWeight"] = self.satWeight
        dict["sunWeight"] = self.sunWeight
        dict["useFitnessGoal"] = self.useFitnessGoal
        dict["capBudget"] = self.capBudget
        dict["capBudgetCals"] = self.capBudgetCals
        dict["finalMealTime"] = self.finalMealTime
        return dict
    }
}

