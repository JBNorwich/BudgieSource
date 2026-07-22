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

// MARK: - Wire format
//
// A backup is deliberately decoupled from the persisted @Model classes (which aren't Codable and
// whose shape we don't want to freeze into a file format). These DTOs are the on-disk schema; the
// read side lives here, and the model-building `init(restoring:)` initialisers live alongside each
// @Model so they can set the otherwise-private `id`.

struct MealDTO: Codable {
    var id: UUID
    var mealUUID: UUID
    var name: String
    var order: Int
    var budgetPercent: Double
    var syncNonce: Int

    init(_ m: Meal) {
        id = m.id; mealUUID = m.mealUUID; name = m.name
        order = m.order; budgetPercent = m.budgetPercent; syncNonce = m.syncNonce
    }
}

struct FoodItemDTO: Codable {
    var id: UUID
    var name: String
    var manufacturer: String?
    var source: FoodSource
    var quantities: [FoodQuantity]
    var archived: Bool
    var barcode: String?
    var dateCreated: Date
    var syncNonce: Int
    // Optional (unlike everything above) so a backup written before custom meals existed still
    // decodes — a missing key just means "not a meal", which FoodItem(restoring:) defaults to.
    var components: [MealComponent]?
    var batchYield: Double?

    init(_ f: FoodItem) {
        id = f.id; name = f.name; manufacturer = f.manufacturer; source = f.source
        quantities = f.quantities; archived = f.archived; barcode = f.barcode
        dateCreated = f.dateCreated; syncNonce = f.syncNonce
        components = f.components; batchYield = f.batchYield
    }
}

struct CalorieEntryDTO: Codable {
    var id: UUID
    var date: Date
    var calories: Int
    var narrative: String?
    var isInHK: Bool
    var healthKitUUID: UUID?
    var meal: UUID
    var foodItem: UUID?
    var manufacturer: String?
    var servingUnit: FoodQuantityType?
    var servingAmount: Double?
    var protein: Double?
    var fat: Double?
    var carbs: Double?
    var syncNonce: Int

    init(_ e: CalorieEntry) {
        id = e.id; date = e.date; calories = e.calories; narrative = e.narrative
        isInHK = e.isInHK; healthKitUUID = e.healthKitUUID; meal = e.meal
        foodItem = e.foodItem; manufacturer = e.manufacturer
        servingUnit = e.servingUnit; servingAmount = e.servingAmount
        protein = e.protein; fat = e.fat; carbs = e.carbs; syncNonce = e.syncNonce
    }
}

struct WaterEntryDTO: Codable {
    var id: UUID
    var date: Date
    var quantity: Int
    var healthKitUUID: UUID?
    var syncNonce: Int

    init(_ w: WaterEntry) {
        id = w.id; date = w.date; quantity = w.quantity
        healthKitUUID = w.healthKitUUID; syncNonce = w.syncNonce
    }
}

/// The exported subset of settings. Fields are optional so a file written by a newer or older build still decodes, and only the keys actually present are applied on restore. Deliberately omits device-local / ephemeral state (the cloud latches, budget snapshot cache, migration flags, "what's new" tracking and the OpenFoodFacts consent gate).
struct SettingsDTO: Codable {
    var desiredDeficit: Int?
    var manualBMR: Int?
    var manualActive: Int?
    var surplusMode: Bool?
    var weight: Int?
    var height: Int?
    var birthYear: Int?
    var impMetric: Int?
    var userSex: Int?
    var bmrMultiplier: Double?
    var whalesEverywhere: Bool?
    var weightingStyle: Int?
    var hideTodayInDetail: Bool?
    var shownExplainer: Bool?
    var donated: Bool?
    var differentWeights: Bool?
    var monWeight: Int?
    var tuesWeight: Int?
    var wedsWeight: Int?
    var thursWeight: Int?
    var friWeight: Int?
    var satWeight: Int?
    var sunWeight: Int?
    var useFitnessGoal: Bool?
    var capBudget: Bool?
    var capBudgetCals: Int?
    var finalMealTime: Int?
    var waterGoal: Int?
    var weightGoal: Double?
    var startWeight: Double?
    var weightDisplayUnit: Int?
    var waterDisplayUnit: Int?
    var useMealAllocations: Bool?
    var waterFromActivity: Bool?
    var disableWeightFeatures: Bool?
    var offSearchDisabled: Bool?
    var disableMacros: Bool?
    var macroGoalMode: Int?
    var proteinGoalGrams: Int?
    var fatGoalGrams: Int?
    var carbsGoalGrams: Int?
    var proteinPercent: Int?
    var fatPercent: Int?
    var carbsPercent: Int?
    var snacksUUID: String?

    init(from s: CloudSettings) {
        desiredDeficit = s.desiredDeficit
        manualBMR = s.manualBMR
        manualActive = s.manualActive
        surplusMode = s.surplusMode
        weight = s.weight
        height = s.height
        birthYear = s.birthYear
        impMetric = s.impMetric
        userSex = s.userSex
        bmrMultiplier = s.bmrMultiplier
        whalesEverywhere = s.whalesEverywhere
        weightingStyle = s.weightingStyle
        hideTodayInDetail = s.hideTodayInDetail
        shownExplainer = s.shownExplainer
        donated = s.donated
        differentWeights = s.differentWeights
        monWeight = s.monWeight
        tuesWeight = s.tuesWeight
        wedsWeight = s.wedsWeight
        thursWeight = s.thursWeight
        friWeight = s.friWeight
        satWeight = s.satWeight
        sunWeight = s.sunWeight
        useFitnessGoal = s.useFitnessGoal
        capBudget = s.capBudget
        capBudgetCals = s.capBudgetCals
        finalMealTime = s.finalMealTime
        waterGoal = s.waterGoal
        weightGoal = s.weightGoal
        startWeight = s.startWeight
        weightDisplayUnit = s.weightDisplayUnit
        waterDisplayUnit = s.waterDisplayUnit
        useMealAllocations = s.useMealAllocations
        waterFromActivity = s.waterFromActivity
        disableWeightFeatures = s.disableWeightFeatures
        offSearchDisabled = s.offSearchDisabled
        disableMacros = s.disableMacros
        macroGoalMode = s.macroGoalMode
        proteinGoalGrams = s.proteinGoalGrams
        fatGoalGrams = s.fatGoalGrams
        carbsGoalGrams = s.carbsGoalGrams
        proteinPercent = s.proteinPercent
        fatPercent = s.fatPercent
        carbsPercent = s.carbsPercent
        snacksUUID = s.snacksUUID?.uuidString
    }

    /// Writes back every value present in the file. Missing keys leave the current setting untouched.
    func apply(to s: CloudSettings) {
        if let v = desiredDeficit { s.desiredDeficit = v }
        if let v = manualBMR { s.manualBMR = v }
        if let v = manualActive { s.manualActive = v }
        if let v = surplusMode { s.surplusMode = v }
        if let v = weight { s.weight = v }
        if let v = height { s.height = v }
        if let v = birthYear { s.birthYear = v }
        if let v = impMetric { s.impMetric = v }
        if let v = userSex { s.userSex = v }
        if let v = bmrMultiplier { s.bmrMultiplier = v }
        if let v = whalesEverywhere { s.whalesEverywhere = v }
        if let v = weightingStyle { s.weightingStyle = v }
        if let v = hideTodayInDetail { s.hideTodayInDetail = v }
        if let v = shownExplainer { s.shownExplainer = v }
        if let v = donated { s.donated = v }
        if let v = differentWeights { s.differentWeights = v }
        if let v = monWeight { s.monWeight = v }
        if let v = tuesWeight { s.tuesWeight = v }
        if let v = wedsWeight { s.wedsWeight = v }
        if let v = thursWeight { s.thursWeight = v }
        if let v = friWeight { s.friWeight = v }
        if let v = satWeight { s.satWeight = v }
        if let v = sunWeight { s.sunWeight = v }
        if let v = useFitnessGoal { s.useFitnessGoal = v }
        if let v = capBudget { s.capBudget = v }
        if let v = capBudgetCals { s.capBudgetCals = v }
        if let v = finalMealTime { s.finalMealTime = v }
        if let v = waterGoal { s.waterGoal = v }
        if let v = weightGoal { s.weightGoal = v }
        if let v = startWeight { s.startWeight = v }
        if let v = weightDisplayUnit { s.weightDisplayUnit = v }
        if let v = waterDisplayUnit { s.waterDisplayUnit = v }
        if let v = useMealAllocations { s.useMealAllocations = v }
        if let v = waterFromActivity { s.waterFromActivity = v }
        if let v = disableWeightFeatures { s.disableWeightFeatures = v }
        if let v = offSearchDisabled { s.offSearchDisabled = v }
        if let v = disableMacros { s.disableMacros = v }
        if let v = macroGoalMode { s.macroGoalMode = v }
        if let v = proteinGoalGrams { s.proteinGoalGrams = v }
        if let v = fatGoalGrams { s.fatGoalGrams = v }
        if let v = carbsGoalGrams { s.carbsGoalGrams = v }
        if let v = proteinPercent { s.proteinPercent = v }
        if let v = fatPercent { s.fatPercent = v }
        if let v = carbsPercent { s.carbsPercent = v }
        if let str = snacksUUID { s.snacksUUID = UUID(uuidString: str) }
        s.sync()
    }
}

/// The full backup file.
struct BudgieBackup: Codable {
    var schemaVersion: Int
    var exportDate: Date
    var appVersion: String?
    var settings: SettingsDTO
    var meals: [MealDTO]
    var foodItems: [FoodItemDTO]
    var calorieEntries: [CalorieEntryDTO]
    var waterEntries: [WaterEntryDTO]
}

// MARK: - Orchestration

enum ImportMode { case merge, replace }

enum BackupService {
    static let schemaVersion = 1

    @MainActor
    static func makeBackup() async -> BudgieBackup {
        let (meals, foods, entries) = await dataStore.calorieActor.exportFoodDomain()
        let water = await dataStore.waterActor.exportWater()
        return BudgieBackup(
            schemaVersion: schemaVersion,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            settings: SettingsDTO(from: settingsObj),
            meals: meals, foodItems: foods,
            calorieEntries: entries, waterEntries: water
        )
    }

    static func encode(_ backup: BudgieBackup) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(backup)
    }

    static func decode(_ data: Data) throws -> BudgieBackup {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(BudgieBackup.self, from: data)
    }

    @MainActor
    static func restore(from backup: BudgieBackup, mode: ImportMode, todayLump: TodayLump) async {
        let merge = (mode == .merge)
        if mode == .replace {
            await dataStore.calorieActor.wipeFoodDomain()
            await dataStore.waterActor.wipeWater()
            backup.settings.apply(to: settingsObj)   // settings ride with a full restore only
        }
        await dataStore.calorieActor.importFoodDomain(
            meals: backup.meals, foods: backup.foodItems,
            entries: backup.calorieEntries, merge: merge
        )
        await dataStore.waterActor.importWater(backup.waterEntries, merge: merge)

        // Collapse any name/signature duplicates a merge introduced against existing data
        // (e.g. the backup's "Breakfast" vs the meal seeded on this install).
        await dataStore.calorieActor.dedupeMeals(preferredSurvivor: settingsObj.snacksUUID)
        await dataStore.calorieActor.dedupeFoods()
        if settingsObj.snacksUUID == nil {
            settingsObj.snacksUUID = await dataStore.calorieActor.getMealUUIDbyName(name: "Snacks/Other")
        }

        await dataStore.updateLump(todayLump: todayLump)
    }
}
