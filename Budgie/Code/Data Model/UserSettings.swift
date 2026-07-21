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

/// Common shape of `NSUbiquitousKeyValueStore` and `UserDefaults` — lets `CloudSettings` and `UserSettings` share one
/// set of accessor implementations instead of each declaring its own.
protocol KeyValueBacking: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}
extension NSUbiquitousKeyValueStore: KeyValueBacking {}
extension UserDefaults: KeyValueBacking {}

/// Settings that are stored identically in `CloudSettings` (iCloud key-value store) and the legacy `UserSettings`
/// (local `UserDefaults`, kept only to migrate existing users into iCloud). Each property's store key is always
/// given explicitly, even when it matches the property name, so that renaming a property here can never silently
/// change which key is read from storage.
protocol SharedSettingsStore: AnyObject {
    var store: KeyValueBacking? { get }
}

extension SharedSettingsStore {
    var onCloud: Bool {
        get { store?.object(forKey: "onCloud") as? Bool ?? false }
        set { store?.set(newValue, forKey: "onCloud") }
    }

    var desiredDeficit: Int {
        get { store?.object(forKey: "desiredDeficit") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "desiredDeficit") }
    }

    var isFirstRun: Bool {
        get { store?.object(forKey: "firstRun") as? Bool ?? true }
        set { store?.set(newValue, forKey: "firstRun") }
    }

    var manualBMR: Int {
        get { store?.object(forKey: "manualBMR") as? Int ?? 2000 }
        set { store?.set(newValue, forKey: "manualBMR") }
    }

    var manualActive: Int {
        get { store?.object(forKey: "manualActive") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "manualActive") }
    }

    var surplusMode: Bool {
        get { store?.object(forKey: "surplusMode") as? Bool ?? false }
        set { store?.set(newValue, forKey: "surplusMode") }
    }

    var weight: Int {
        get { store?.object(forKey: "weight") as? Int ?? 90 }
        set { store?.set(newValue, forKey: "weight") }
    }

    var height: Int {
        get { store?.object(forKey: "height") as? Int ?? 175 }
        set { store?.set(newValue, forKey: "height") }
    }

    var birthYear: Int {
        get { store?.object(forKey: "birthYear") as? Int ?? 2000 }
        set { store?.set(newValue, forKey: "birthYear") }
    }

    var impMetric: Int {
        get { store?.object(forKey: "impMetric") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "impMetric") }
    }

    /// The stored key predates this property's current name and is not renamed, to avoid orphaning existing users'
    /// stored value.
    var userSex: Int {
        get { store?.object(forKey: "userGender") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "userGender") }
    }

    var bmrMultiplier: Double {
        get { store?.object(forKey: "bmrMultiplier") as? Double ?? 0.2 }
        set { store?.set(newValue, forKey: "bmrMultiplier") }
    }

    var whalesEverywhere: Bool {
        get { store?.object(forKey: "whalesEverywhere") as? Bool ?? false }
        set { store?.set(newValue, forKey: "whalesEverywhere") }
    }

    /// 0 is regular. -1 is forgiving. 1 is harsh. 2 is no projection at all. -2 is no weighting down. 3 is the old (pre-quotient) default.
    var weightingStyle: Int {
        get { store?.object(forKey: "weightingStyle") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "weightingStyle") }
    }

    var hideTodayInDetail: Bool {
        get { store?.object(forKey: "hideTodayInDetail") as? Bool ?? true }
        set { store?.set(newValue, forKey: "hideTodayInDetail") }
    }

    var shownExplainer: Bool {
        get { store?.object(forKey: "shownExplainer") as? Bool ?? false }
        set { store?.set(newValue, forKey: "shownExplainer") }
    }

    var donated: Bool {
        get { store?.object(forKey: "donated") as? Bool ?? false }
        set { store?.set(newValue, forKey: "donated") }
    }

    var differentWeights: Bool {
        get { store?.object(forKey: "differentWeights") as? Bool ?? false }
        set { store?.set(newValue, forKey: "differentWeights") }
    }

    var monWeight: Int {
        get { store?.object(forKey: "monWeight") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "monWeight") }
    }

    var tuesWeight: Int {
        get { store?.object(forKey: "tuesWeight") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "tuesWeight") }
    }

    var wedsWeight: Int {
        get { store?.object(forKey: "wedsWeight") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "wedsWeight") }
    }

    var thursWeight: Int {
        get { store?.object(forKey: "thursWeight") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "thursWeight") }
    }

    var friWeight: Int {
        get { store?.object(forKey: "friWeight") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "friWeight") }
    }

    var satWeight: Int {
        get { store?.object(forKey: "satWeight") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "satWeight") }
    }

    var sunWeight: Int {
        get { store?.object(forKey: "sunWeight") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "sunWeight") }
    }

    var useFitnessGoal: Bool {
        get { store?.object(forKey: "useFitnessGoal") as? Bool ?? false }
        set { store?.set(newValue, forKey: "useFitnessGoal") }
    }

    var capBudget: Bool {
        get { store?.object(forKey: "capBudget") as? Bool ?? false }
        set { store?.set(newValue, forKey: "capBudget") }
    }

    var capBudgetCals: Int {
        get { store?.object(forKey: "capBudgetCals") as? Int ?? 2000 }
        set { store?.set(newValue, forKey: "capBudgetCals") }
    }

    var finalMealTime: Int {
        get { store?.object(forKey: "finalMealTime") as? Int ?? 1080 }
        set { store?.set(newValue, forKey: "finalMealTime") }
    }

    var waterGoal: Int {
        get { store?.object(forKey: "waterGoal") as? Int ?? 2000 }
        set { store?.set(newValue, forKey: "waterGoal") }
    }

    var weightGoal: Double {
        get { store?.object(forKey: "weightGoal") as? Double ?? 0 }
        set { store?.set(newValue, forKey: "weightGoal") }
    }

    var startWeight: Double {
        get { store?.object(forKey: "startWeight") as? Double ?? 0 }
        set { store?.set(newValue, forKey: "startWeight") }
    }

    var weightDisplayUnit: Int {
        get { store?.object(forKey: "weightDisplayUnit") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "weightDisplayUnit") }
    }
}

/// Class used for querying iCloud hosted key-value storage.
class CloudSettings: SharedSettingsStore {
    let store: KeyValueBacking? = NSUbiquitousKeyValueStore.default

    func sync() {
        NSUbiquitousKeyValueStore.default.synchronize()
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

    var snacksUUID: UUID? {
        get {
            guard let uuidString = store?.object(forKey: "snacksUUID") as? String else {
                return nil
            }
            return UUID(uuidString: uuidString)
        }
        set { store?.set(newValue?.uuidString, forKey: "snacksUUID") }
    }

    var waterDisplayUnit: Int {
        get { store?.object(forKey: "waterDisplayUnit") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "waterDisplayUnit") }
    }

    var useMealAllocations: Bool {
        get { store?.object(forKey: "useMealAllocations") as? Bool ?? false }
        set { store?.set(newValue, forKey: "useMealAllocations") }
    }

    var waterFromActivity: Bool {
        get { store?.object(forKey: "waterFromActivity") as? Bool ?? false }
        set { store?.set(newValue, forKey: "waterFromActivity") }
    }

    var disableWeightFeatures: Bool {
        get { store?.object(forKey: "disableWeightFeatures") as? Bool ?? false }
        set { store?.set(newValue, forKey: "disableWeightFeatures") }
    }

    // MARK: - Budget snapshot (published by the iPhone for platforms without HealthKit)

    /// The most recent total daily budget the iPhone calculated. Not live — always show it alongside `budgetSnapshotDate` so the user knows how current it is.
    var snapshotBudget: Int {
        get { store?.object(forKey: "snapshotBudget") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "snapshotBudget") }
    }
    var snapshotAtCap: Bool {
        get { store?.object(forKey: "snapshotAtCap") as? Bool ?? false }
        set { store?.set(newValue, forKey: "snapshotAtCap") }
    }
    var snapshotAtMin: Bool {
        get { store?.object(forKey: "snapshotAtMin") as? Bool ?? false }
        set { store?.set(newValue, forKey: "snapshotAtMin") }
    }
    /// When the iPhone last published the snapshot (seconds since 1970). 0 means never.
    var snapshotTimestamp: Double {
        get { store?.object(forKey: "snapshotTimestamp") as? Double ?? 0 }
        set { store?.set(newValue, forKey: "snapshotTimestamp") }
    }
    /// The snapshot's publish time, or nil if nothing has been published yet.
    var budgetSnapshotDate: Date? {
        snapshotTimestamp > 0 ? Date(timeIntervalSince1970: snapshotTimestamp) : nil
    }
    /// Whether the snapshot is recent enough to derive a live "left to eat" figure from: published today AND within the last four hours. (The budget resets at midnight, so a pre-midnight snapshot is stale regardless of clock age.)
    var budgetSnapshotIsFresh: Bool {
        guard let date = budgetSnapshotDate, Calendar.current.isDateInToday(date) else { return false }
        return Date().timeIntervalSince(date) < 4 * 60 * 60
    }

    var snapshotActiveCalories: Int {
        get { store?.object(forKey: "snapshotActiveCalories") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "snapshotActiveCalories") }
    }

    var snapshotBasalCalories: Int {
        get { store?.object(forKey: "snapshotBasalCalories") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "snapshotBasalCalories") }
    }

    var snapShotHKCalories: Int {
        get { store?.object(forKey: "snapshotHKCalories") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "snapshotHKCalories") }
    }

    var snapShotHKWater: Int {
        get { store?.object(forKey: "snapshotHKWater") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "snapshotHKWater") }
    }

    var snapshotProjectedBasal: Int {
        get { store?.object(forKey: "snapshotProjectedBasal") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "snapshotProjectedBasal") }
    }

    var snapshotProjectedActive: Int {
        get { store?.object(forKey: "snapshotProjectedActive") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "snapshotProjectedActive") }
    }

    var snapShotHKProtein: Int {
        get { store?.object(forKey: "snapshotHKProtein") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "snapshotHKProtein") }
    }
    var snapShotHKFat: Int {
        get { store?.object(forKey: "snapshotHKFat") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "snapshotHKFat") }
    }
    var snapShotHKCarbs: Int {
        get { store?.object(forKey: "snapshotHKCarbs") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "snapshotHKCarbs") }
    }

    /// The `whatsNewVersion` whose "What's New" sheet the user has already seen. Defaults to "2.0" so everyone upgrading from an older build sees the current sheet once. Holds thee *content* version, not the bundle version — it's shared via iCloud and the iOS/Mac apps carry different bundle versions.
    var lastOpenedVersion: String {
        get { store?.object(forKey: "lastOpenedVersion") as? String ?? "3.2" }
        set { store?.set(newValue, forKey: "lastOpenedVersion") }
    }

    /// Whether the last published snapshot was computed from estimated (manual) activity rather than real HealthKit data. Lets publishers avoid downgrading a real snapshot with a background estimated one (e.g. a locked-phone recompute with no HK access).
    var snapshotEstimated: Bool {
        get { store?.object(forKey: "snapshotEstimated") as? Bool ?? false }
        set { store?.set(newValue, forKey: "snapshotEstimated") }
    }

    var hasDoneFoodItemMigration: Bool {
        get { store?.object(forKey: "hasDoneFoodItemMigration") as? Bool ?? false }
        set { store?.set(newValue, forKey: "hasDoneFoodItemMigration") }
    }

    var offSearchDisabled: Bool {
        get { store?.object(forKey: "offSearchDisabled") as? Bool ?? false }
        set { store?.set(newValue, forKey: "offSearchDisabled") }
    }

    var offSearchConsented: Bool {
        get { store?.object(forKey: "offSearchConsented") as? Bool ?? false }
        set { store?.set(newValue, forKey: "offSearchConsented") }
    }

    // MARK: - Macros

    /// Master switch for the whole macro feature. Default off = macros ON, matching disableWeightFeatures / offSearchDisabled.
    var disableMacros: Bool {
        get { store?.object(forKey: "disableMacros") as? Bool ?? false }
        set { store?.set(newValue, forKey: "disableMacros") }
    }

    /// 0 = no goal, 1 = fixed grams, 2 = percentage of the daily budget.
    var macroGoalMode: Int {
        get { store?.object(forKey: "macroGoalMode") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "macroGoalMode") }
    }

    /// Fixed gram targets (macroGoalMode == 1). 0 means "not set" — that macro shows its total only, no ring.
    var proteinGoalGrams: Int {
        get { store?.object(forKey: "proteinGoalGrams") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "proteinGoalGrams") }
    }
    var fatGoalGrams: Int {
        get { store?.object(forKey: "fatGoalGrams") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "fatGoalGrams") }
    }
    var carbsGoalGrams: Int {
        get { store?.object(forKey: "carbsGoalGrams") as? Int ?? 0 }
        set { store?.set(newValue, forKey: "carbsGoalGrams") }
    }

    /// Percentage-of-budget split (macroGoalMode == 2). Defaults 30/30/40 — a balanced starting point, not attributed to any authority. Kept summing to 100 by the settings UI.
    var proteinPercent: Int {
        get { store?.object(forKey: "proteinPercent") as? Int ?? 30 }
        set { store?.set(newValue, forKey: "proteinPercent") }
    }
    var fatPercent: Int {
        get { store?.object(forKey: "fatPercent") as? Int ?? 30 }
        set { store?.set(newValue, forKey: "fatPercent") }
    }
    var carbsPercent: Int {
        get { store?.object(forKey: "carbsPercent") as? Int ?? 40 }
        set { store?.set(newValue, forKey: "carbsPercent") }
    }

    /// The effective per-macro gram goals for the day, or nil where no goal applies (mode off, or a grams-mode value left at 0). Percentage mode derives grams from `budget` at 4 kcal/g (protein, carbs) and 9 kcal/g (fat). Central so the rings and any preview all read the same figures.
    func macroGoalGrams(budget: Int) -> (protein: Int?, fat: Int?, carbs: Int?) {
        switch macroGoalMode {
        case 1:
            return (proteinGoalGrams > 0 ? proteinGoalGrams : nil,
                    fatGoalGrams    > 0 ? fatGoalGrams    : nil,
                    carbsGoalGrams  > 0 ? carbsGoalGrams  : nil)
        case 2:
            guard budget > 0 else { return (nil, nil, nil) }
            let grams: (Int, Double) -> Int = { pct, kcalPerGram in
                Int((Double(budget) * Double(pct) / 100.0 / kcalPerGram).rounded())
            }
            return (grams(proteinPercent, 4), grams(fatPercent, 9), grams(carbsPercent, 4))
        default:
            return (nil, nil, nil)
        }
    }
}

/// Legacy class for local-only settings storage via UserDefaults. Only kept around to migrate existing users to CloudKit.
class UserSettings: SharedSettingsStore {
    let store: KeyValueBacking?

    init() {
        store = UserDefaults(suiteName: "group.JoeBaldwin.Budgie")
    }
}
