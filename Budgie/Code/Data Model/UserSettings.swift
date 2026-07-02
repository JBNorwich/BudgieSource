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
import SwiftData

/// Class used for querying iCloud hosted key-value storage.
class CloudSettings {
    private let defaults = NSUbiquitousKeyValueStore.default
    
    func sync() {
        defaults.synchronize()
    }
    
    /// Function to copy existing settings from UserSettings into the CloudKit based storage.
    func copyFromLocal(localObj: UserSettings) {
        self.desiredDeficit = localObj.desiredDeficit
        self.isFirstRun = localObj.isFirstRun
        self.manualBMR = localObj.manualBMR
        self.manualActive = localObj.manualActive
        self.surplusMode = localObj.surplusMode
        self.weight = localObj.weight
        self.height = localObj.height
        self.birthYear = localObj.birthYear
        self.impMetric = localObj.impMetric
        self.userSex = localObj.userSex
        self.bmrMultiplier = localObj.bmrMultiplier
        self.whalesEverywhere = localObj.whalesEverywhere
        self.weightingStyle = localObj.weightingStyle
        self.hideTodayInDetail = localObj.hideTodayInDetail
        self.shownExplainer = localObj.shownExplainer
        self.donated = localObj.donated
        self.differentWeights = localObj.differentWeights
        self.monWeight = localObj.monWeight
        self.tuesWeight = localObj.tuesWeight
        self.wedsWeight = localObj.wedsWeight
        self.thursWeight = localObj.thursWeight
        self.friWeight = localObj.friWeight
        self.satWeight = localObj.satWeight
        self.sunWeight = localObj.sunWeight
        self.useFitnessGoal = localObj.useFitnessGoal
        self.capBudget = localObj.capBudget
        self.capBudgetCals = localObj.capBudgetCals
        self.finalMealTime = localObj.finalMealTime
        self.waterGoal = localObj.waterGoal
        self.weightGoal = localObj.weightGoal
        self.startWeight = localObj.startWeight
        self.weightDisplayUnit = localObj.weightDisplayUnit

        print("All settings copied to iCloud")
        self.onCloud = true
        localObj.onCloud = true
        self.sync()
    }
    
    var onCloud: Bool {
        get { return defaults.object(forKey: "onCloud") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "onCloud")}
    }
    
    var desiredDeficit: Int {
        get { return defaults.object(forKey: "desiredDeficit") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "desiredDeficit")}
    }
    
    var isFirstRun: Bool {
        get { return defaults.object(forKey: "firstRun") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "firstRun")}
    }
    
    var manualBMR: Int {
        get { return defaults.object(forKey: "manualBMR") as? Int ?? 2000 }
        set { defaults.set(newValue, forKey: "manualBMR")}
    }
    
    var manualActive: Int {
        get { return defaults.object(forKey: "manualActive") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "manualActive")}
    }
    
    var surplusMode: Bool {
        get { return defaults.object(forKey: "surplusMode") as? Bool ?? false}
        set { defaults.set(newValue, forKey: "surplusMode")}
    }
    
    var weight: Int {
        get { return defaults.object(forKey: "weight") as? Int ?? 90 }
        set { defaults.set(newValue, forKey: "weight")}
    }
    
    var height: Int {
        get { return defaults.object(forKey: "height") as? Int ?? 175 }
        set { defaults.set(newValue, forKey: "height")}
    }
    
    var birthYear: Int {
        get { return defaults.object(forKey: "birthYear") as? Int ?? 2000 }
        set { defaults.set(newValue, forKey: "birthYear")}
    }
    
    var impMetric: Int {
        get { return defaults.object(forKey: "impMetric") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "impMetric")}
    }
    
    var userSex: Int {
        get { return defaults.object(forKey: "userGender") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "userGender")}
    }
    
    var bmrMultiplier: Double {
        get { return defaults.object(forKey: "bmrMultiplier") as? Double ?? 0.2 }
        set { defaults.set(newValue, forKey: "bmrMultiplier")}
    }
    
    var whalesEverywhere: Bool {
        get { return defaults.object(forKey: "whalesEverywhere") as? Bool ?? false}
        set { defaults.set(newValue, forKey: "whalesEverywhere")}
    }
    
    /// 0 is regular. -1 is forgiving. 1 is harsh. 2 is no projection at all.
    var weightingStyle: Int {
        get { return defaults.object(forKey: "weightingStyle") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "weightingStyle")}
    }
    
    var hideTodayInDetail: Bool {
        get { return defaults.object(forKey: "hideTodayInDetail") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hideTodayInDetail")}
    }
    
    var shownExplainer: Bool {
        get { return defaults.object(forKey: "shownExplainer") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "shownExplainer")}
    }
    
    var donated: Bool {
        get { return defaults.object(forKey: "donated") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "donated")}
    }
    
    var differentWeights: Bool {
        get { return defaults.object(forKey: "differentWeights") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "differentWeights")}
    }
    
    var monWeight: Int {
        get { return defaults.object(forKey: "monWeight") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "monWeight")}
    }
    
    var tuesWeight: Int {
        get { return defaults.object(forKey: "tuesWeight") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "tuesWeight")}
    }
    
    var wedsWeight: Int {
        get { return defaults.object(forKey: "wedsWeight") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "wedsWeight")}
    }
    
    var thursWeight: Int {
        get { return defaults.object(forKey: "thursWeight") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "thursWeight")}
    }
    
    var friWeight: Int {
        get { return defaults.object(forKey: "friWeight") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "friWeight")}
    }
    
    var satWeight: Int {
        get { return defaults.object(forKey: "satWeight") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "satWeight")}
    }
    
    var sunWeight: Int {
        get { return defaults.object(forKey: "sunWeight") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "sunWeight")}
    }
    
    var useFitnessGoal: Bool {
        get { return defaults.object(forKey: "useFitnessGoal") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "useFitnessGoal")}
    }
    
    var capBudget: Bool {
        get { return defaults.object(forKey: "capBudget") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "capBudget")}
    }
    
    var capBudgetCals: Int {
        get { return defaults.object(forKey: "capBudgetCals") as? Int ?? 2000 }
        set { defaults.set(newValue, forKey: "capBudgetCals")}
    }
    
    var finalMealTime: Int {
        get { return defaults.object(forKey: "finalMealTime") as? Int ?? 1080 }
        set { defaults.set(newValue, forKey: "finalMealTime")}
    }
    
    var waterGoal: Int {
        get { return defaults.object(forKey: "waterGoal") as? Int ?? 2000 }
        set { defaults.set(newValue, forKey: "waterGoal")}
    }
    
    var weightGoal: Double {
        get { return defaults.object(forKey: "weightGoal") as? Double ?? 0 }
        set { defaults.set(newValue, forKey: "weightGoal") }
    }
    
    var startWeight: Double {
        get { return defaults.object(forKey: "startWeight") as? Double ?? 0 }
        set { defaults.set(newValue, forKey: "startWeight") }
    }
    
    var weightDisplayUnit: Int {
        get { return defaults.object(forKey: "weightDisplayUnit") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "weightDisplayUnit")}
    }
    
    var snacksUUID: UUID? {
        get {
            guard let uuidString = defaults.string(forKey: "snacksUUID") else {
                return nil
            }
            return UUID(uuidString: uuidString)
        }
        set { defaults.set(newValue?.uuidString, forKey: "snacksUUID")}
    }
    
    var waterDisplayUnit: Int {
        get { return defaults.object(forKey: "waterDisplayUnit") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "waterDisplayUnit")}
    }
}

/// Legacy class for local-only settings storage via UserDefaults. Only kept around to migrate existing users to CloudKit.
class UserSettings {
    private let defaults = UserDefaults(suiteName: "group.JoeBaldwin.Budgie")
    
    init()
    {
        
    }
    
    var onCloud: Bool {
        get { return defaults?.value(forKey: "firstRun") as? Bool ?? false }
        set { defaults?.set(newValue, forKey: "firstRun")}
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
        set { defaults?.set(newValue, forKey: "bmrMultiplier")}
    }
    
    var whalesEverywhere: Bool {
        get { return defaults?.value(forKey: "whalesEverywhere") as? Bool ?? false}
        set { defaults?.set(newValue, forKey: "whalesEverywhere")}
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
        get { return defaults?.value(forKey: "donated") as? Bool ?? false }
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
    
    var weightDisplayUnit: Int {
        get { return defaults?.value(forKey: "weightDisplayUnit") as? Int ?? 0 }
        set { defaults?.set(newValue, forKey: "weightDisplayUnit")}
    }
}

