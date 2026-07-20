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

import AppIntents

extension HealthData {
    /// Convenience for App Intents/Shortcuts, which repeatedly need a fresh, throwaway `TodayLump`
    /// either just to read a figure off of or purely to trigger the refresh's side effects (recalculating
    /// the budget, and — on iOS — republishing the snapshot other platforms read). Never publishes that
    /// snapshot itself: a Shortcut run isn't the authoritative foreground pass. `reloadWidgets` is left
    /// to the caller since intents that only read a value skip it, while ones that log something don't.
    @MainActor
    func freshLump(reloadWidgets: Bool) async -> TodayLump {
        let lump = TodayLump()
        await updateLump(todayLump: lump, reloadWidgets: reloadWidgets, publishSnapshot: false)
        return lump
    }
}

struct LogQuickCaloriesIntent: AppIntent {
    // Logs calories to the "Snacks/Other" meal
    static var title: LocalizedStringResource = "Log quick calories"
    static var description = IntentDescription("Logs calories to Budgie Diet as a snack.")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Calories", requestValueDialog: "The number of calories to log.")
    var calories: Int!
    
    static var parameterSummary: some ParameterSummary {
            Summary("Log \(\.$calories) quick calories.")
        }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var calsToLog: Int
        
        if let calories = calories {
            calsToLog = calories
        } else {
            calsToLog = try await $calories.requestValue(.init(stringLiteral: "How many calories did you eat?"))
        }
        
        guard let snacksUUID = settingsObj.snacksUUID else {
            throw $calories.needsValueError("Budgie Diet hasn't finished setting up yet — please open the app first.")
        }
        await dataStore.addCalories(calories: calsToLog, narrative: nil, date: Date(), meal: snacksUUID)
        _ = await dataStore.freshLump(reloadWidgets: true)

        return .result(dialog: "Logged \(calsToLog.formatted()) kcal.")
    }
}

struct LogFoodIntent: AppIntent {
    // Logs custom food with a proper narrative into a meal of the user's choice
    static var title: LocalizedStringResource = "Log food"
    static var description = IntentDescription("Logs food to a meal in Budgie Diet.")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Calories", requestValueDialog: "The number of calories to log.")
    var calories: Int!
    
    @Parameter(title: "Food", requestValueDialog: "The name of the food eaten.")
    var narrative: String!
    
    @Parameter(title: "Meal", requestValueDialog: "The meal to log to.", optionsProvider: MealOptionsProvider())
    var meal: MealEntity!
    
    private struct MealOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [MealEntity] {
            return try await StructMealQuery().suggestedEntities()
        }
    }
    
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        // Narrative first, so we can resolve a saved food before deciding whether we even need a number.
        let narrativeToLog: String
        if let narrative { narrativeToLog = narrative }
        else { narrativeToLog = try await $narrative.requestValue(.init(stringLiteral: "What did you eat?")) }

        if meal == nil {
            meal = try await $meal.requestValue(.init(stringLiteral: "What meal should this be logged to?"))
        }

        // Resolve to a saved food (unique, non-archived exact-name match); else a bundled generic of the same name.
        let named = await dataStore.foodItemActor.picked(named: narrativeToLog)
        let food: PickedFood?
        if named.count == 1 {
            food = named.first
        } else if named.isEmpty {
            food = FoodCatalogue.shared.foods
                .first { $0.name.caseInsensitiveCompare(narrativeToLog) == .orderedSame }?.asPicked
        } else {
            food = nil   // ambiguous saved-name match → quick calories
        }

        if let provided = calories {
            // A number was given: link to the food only if the name AND a serving's calories both match;
            // otherwise it's quick calories at the number they gave.
            if let food, let q = food.quantities.first(where: { $0.calories == provided }) {
                await logServing(food, q)
                await refreshBudget()
                return .result(dialog: "Logged \(provided.formatted()) kcal of \(food.name) to \(meal.name).")
            }
            await dataStore.addCalories(calories: provided, narrative: narrativeToLog, date: Date(), meal: meal.id)
            await refreshBudget()
            return .result(dialog: "Logged \(provided.formatted()) kcal for \(narrativeToLog) to \(meal.name).")
        } else if let food, let q = food.quantities.first, q.calories > 0 {
            // No number, but the name matches a saved food → one serving at its own calories.
            await logServing(food, q)
            await refreshBudget()
            return .result(dialog: "Logged \(q.calories.formatted()) kcal of \(food.name) to \(meal.name).")
        } else {
            // No number and no matching food → ask, then quick calories.
            let asked = try await $calories.requestValue(.init(stringLiteral: "How many calories did you eat?"))
            await dataStore.addCalories(calories: asked, narrative: narrativeToLog, date: Date(), meal: meal.id)
            await refreshBudget()
            return .result(dialog: "Logged \(asked.formatted()) kcal for \(narrativeToLog) to \(meal.name).")
        }
    }

    private func logServing(_ food: PickedFood, _ q: FoodQuantity) async {
        await dataStore.addFoodEntry(foodItemID: food.persistedID, name: food.name,
                                     manufacturer: food.manufacturer, quantity: q,
                                     servings: 1, date: Date(), meal: meal.id)
    }

    private func refreshBudget() async {
        _ = await dataStore.freshLump(reloadWidgets: true)
    }
}

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log water"
    
    static var description: IntentDescription = IntentDescription("Logs water to Budgie Diet.")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Millitres", requestValueDialog: "The amount of water to log, in millilitres.")
    var millilitres: Int!
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$millilitres)ml of water.")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var mlsToLog: Int
        
        if let millilitres = millilitres {
            mlsToLog = millilitres
        } else {
            mlsToLog = try await $millilitres.requestValue(.init(stringLiteral: "How much water did you drink, in millilitres?"))
        }
        
        await dataStore.addWater(amount: mlsToLog, datetime: Date())
        
        return .result(dialog: "Logged \(renderVolume(millilitres: mlsToLog)).")
    }
}

struct GetCanEatNowIntent: AppIntent {
    static var title: LocalizedStringResource = "Get calories I can eat now"
    static var description = IntentDescription("Returns how many calories you can eat right now as a variable for a Shortcut.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let lump = await dataStore.freshLump(reloadWidgets: false)
        return .result(value: lump.canEatNow)
    }
}

struct GetBudgetRemainingIntent: AppIntent {
    static var title: LocalizedStringResource = "Get remaining calorie budget"
    static var description = IntentDescription(
        "Returns how many calories are left in today's budget as a variable in a Shortcut.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let lump = await dataStore.freshLump(reloadWidgets: false)
        return .result(value: lump.totalBudgetRem)
    }
}

struct SpeakCanEatNowIntent: AppIntent {
    static var title: LocalizedStringResource = "How many calories can I eat now"
    static var description = IntentDescription(
        "Tells you how many calories you can eat right now while staying on target.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let lump = await dataStore.freshLump(reloadWidgets: false)

        // With meal allocations on, "can eat now" isn't a user-facing figure — the app
        // replaces it with remaining budget, so answer in those terms to stay consistent.
        if settingsObj.useMealAllocations {
            let v = lump.totalBudgetRem
            let dialog: IntentDialog = v >= 0
                ? "You have \(v.formatted()) calories left in your budget today."
                : "You're about \((-v).formatted()) calories over your budget today."
            return .result(dialog: dialog)
        }

        let v = lump.canEatNow
        let dialog: IntentDialog = v >= 0
            ? "You can eat \(v.formatted()) calories now."
            : "You're about \((-v).formatted()) calories over your target for now."
        return .result(dialog: dialog)
    }
}

struct SpeakBudgetRemainingIntent: AppIntent {
    static var title: LocalizedStringResource = "How much calorie budget do I have left"
    static var description = IntentDescription(
        "Tells you how many calories are left in today's budget.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let lump = await dataStore.freshLump(reloadWidgets: false)
        let v = lump.totalBudgetRem
        let dialog: IntentDialog = v >= 0
            ? "You have \(v.formatted()) calories left in your budget today."
            : "You're about \((-v).formatted()) calories over your budget today."
        return .result(dialog: dialog)
    }
}

struct LogFoodShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
        static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: LogQuickCaloriesIntent(),
                phrases: [
                    "Log quick calories with \(.applicationName)"
                ],
                shortTitle: "Log quick calories",
                systemImageName: "fork.knife"
            )
            AppShortcut(
                intent: LogWaterIntent(),
                phrases: [
                    "Log water with \(.applicationName)"
                ],
                shortTitle: "Log water",
                systemImageName: "drop.fill"
            )
            AppShortcut(
                intent: LogFoodIntent(),
                phrases: [
                    "Log food with \(.applicationName)"
                ],
                shortTitle: "Log food",
                systemImageName: "fork.knife"
            )
            AppShortcut(
                intent: LogSavedFoodIntent(),
                phrases: [
                    "Log a saved food with \(.applicationName)"
                ],
                shortTitle: "Log a saved food",
                systemImageName: "carrot"
            )
            #if !os(macOS)
            AppShortcut(
                intent: LogWeightIntent(),
                phrases: [
                    "Log my weight with \(.applicationName)"
                ],
                shortTitle: "Log weight",
                systemImageName: "scalemass.fill"
            )
            #endif
        }
}

struct LogSavedFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a saved food"
    static var description = IntentDescription("Logs a serving of one of your saved foods to a meal in Budgie Diet.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Food", requestValueDialog: "Which saved food?")
    var food: FoodEntity!

    // Options depend on the chosen food (provider below); left unset → the food's primary serving.
    @Parameter(title: "Serving", optionsProvider: ServingOptionsProvider())
    var serving: FoodServingEntity?

    @Parameter(title: "Servings", default: 1.0)
    var servings: Double

    @Parameter(title: "Meal", requestValueDialog: "Which meal?", optionsProvider: MealOptionsProvider())
    var meal: MealEntity!

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$servings) × \(\.$serving) of \(\.$food) to \(\.$meal)")
    }

    private struct MealOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [MealEntity] { try await StructMealQuery().suggestedEntities() }
    }

    private struct ServingOptionsProvider: DynamicOptionsProvider {
        @IntentParameterDependency<LogSavedFoodIntent>(\.$food)
        var input

        func results() async throws -> [FoodServingEntity] {
            guard let input,
                  let picked = await dataStore.foodItemActor.picked(id: input.food.id) else { return [] }
            return picked.quantities.enumerated().map { idx, q in
                FoodServingEntity(foodID: input.food.id, index: idx, label: q.label)
            }
        }
    }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        if food == nil { food = try await $food.requestValue() }
        if meal == nil { meal = try await $meal.requestValue() }
        guard servings > 0 else { throw $servings.needsValueError("Enter a number of servings above zero.") }

        guard let item = await dataStore.foodItemActor.picked(id: food.id), !item.quantities.isEmpty else {
            return .result(dialog: "I couldn't find that saved food any more — it may have been removed.")
        }
        // Resolve the chosen serving by its stable index, guarding it belongs to this food; else primary serving.
        let q: FoodQuantity
        if let s = serving, s.foodID == food.id, let idx = s.index, item.quantities.indices.contains(idx) {
            q = item.quantities[idx]
        } else {
            q = item.quantities.first!
        }

        await dataStore.addFoodEntry(foodItemID: item.persistedID, name: item.name,
                                     manufacturer: item.manufacturer, quantity: q,
                                     servings: servings, date: Date(), meal: meal.id)
        _ = await dataStore.freshLump(reloadWidgets: true)
        let cals = q.totals(servings: servings).calories
        return .result(dialog: "Logged \(servings.formatted()) × \(q.label) of \(item.name) — \(cals.formatted()) kcal — to \(meal.name).")
    }
}

#if !os(macOS)
struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Log weight"
    static var description = IntentDescription("Logs a weight measurement to Health via Budgie Diet.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Weight (kg)", requestValueDialog: "What do you weigh, in kilograms?")
    var kilograms: Double!

    static var parameterSummary: some ParameterSummary {
        Summary("Log a weight of \(\.$kilograms)kg.")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var toLog: Double
        if let kilograms {
            toLog = kilograms
        } else {
            toLog = try await $kilograms.requestValue(.init(stringLiteral: "What do you weigh, in kilograms?"))
        }
        guard toLog > 0 else {
            throw $kilograms.needsValueError("Weight must be above zero.")
        }
        let uuid = await dataStore.saveHKSample(value: toLog, unit: .gramUnit(with: .kilo), type: weightSampleType, date: Date())
        guard uuid != nil else {
            return .result(dialog: "I couldn't save that. Check that Budgie Diet is allowed to write weight data in the Health app.")
        }
        return .result(dialog: "Logged \(renderWeight(kilos: toLog)).")
    }
}
#endif

struct MealEntity: AppEntity, Identifiable {
    var id: UUID
    
    @Property(title: "Meal")
    var name: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static var defaultQuery = StructMealQuery()
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Meal"
    
    // the UUID here is the internal "mealUUID" of the Meal object in the data store
    init(mealUUID: UUID, name: String) {
        self.id = mealUUID
        self.name = name
    }
}

struct StructMealQuery: EntityQuery {
    func entities(for identifiers: [MealEntity.ID]) async throws -> [MealEntity] {
        let mealObjects = await dataStore.calorieActor.getListOfMeals()
        return mealObjects
            .filter { identifiers.contains($0.mealUUID) }
            .map { MealEntity(mealUUID: $0.mealUUID, name: $0.name) }
    }
    
    func suggestedEntities() async throws -> [MealEntity] {
        let mealObjects = await dataStore.calorieActor.getListOfMeals()
        return mealObjects.map { MealEntity(mealUUID: $0.mealUUID, name: $0.name) }
    }
}

struct FoodEntity: AppEntity, Identifiable {
    var id: UUID
    @Property(title: "Food") var name: String
    var manufacturer: String?
    
    init(id: UUID, name: String, manufacturer: String?) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
    }

    var displayRepresentation: DisplayRepresentation {
        if let m = manufacturer, !m.isEmpty { return DisplayRepresentation(title: "\(name)", subtitle: "\(m)") }
        return DisplayRepresentation(title: "\(name)")
    }
    static var defaultQuery = FoodQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Food"
}

struct FoodQuery: EntityQuery {
    func entities(for identifiers: [FoodEntity.ID]) async throws -> [FoodEntity] {
        let all = await dataStore.foodItemActor.allPicked()
        return all.filter { identifiers.contains($0.persistedID ?? $0.id) }
                  .map { FoodEntity(id: $0.persistedID ?? $0.id, name: $0.name, manufacturer: $0.manufacturer) }
    }
    func suggestedEntities() async throws -> [FoodEntity] {
        (await dataStore.foodItemActor.allPicked())
            .map { FoodEntity(id: $0.persistedID ?? $0.id, name: $0.name, manufacturer: $0.manufacturer) }
    }
}

extension FoodQuery: EntityStringQuery {
    // Lets Siri/Shortcuts match a spoken/typed food name to one of your foods.
    func entities(matching string: String) async throws -> [FoodEntity] {
        (await dataStore.foodItemActor.allPicked())
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map { FoodEntity(id: $0.persistedID ?? $0.id, name: $0.name, manufacturer: $0.manufacturer) }
    }
}

/// One serving definition of a specific saved food. The id encodes "<foodUUID>#<serving index>", so a saved
/// Shortcut resolves back to the exact serving by position — immune to that serving later being renamed.
struct FoodServingEntity: AppEntity, Identifiable {
    var id: String
    @Property(title: "Serving") var label: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(label)") }
    static var defaultQuery = FoodServingQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Serving"

    var foodID: UUID? { UUID(uuidString: id.components(separatedBy: "#").first ?? "") }
    var index: Int? { Int(id.components(separatedBy: "#").last ?? "") }

    init(foodID: UUID, index: Int, label: String) {
        self.id = "\(foodID.uuidString)#\(index)"
        self.label = label
    }
    init(id: String, label: String) { self.id = id; self.label = label }
}

struct FoodServingQuery: EntityQuery {
    // Reconstructs a stored serving from its id, re-reading the current label (so a rename shows through).
    func entities(for identifiers: [String]) async throws -> [FoodServingEntity] {
        var out: [FoodServingEntity] = []
        for idString in identifiers {
            let probe = FoodServingEntity(id: idString, label: "")
            guard let foodID = probe.foodID, let index = probe.index,
                  let picked = await dataStore.foodItemActor.picked(id: foodID),
                  picked.quantities.indices.contains(index) else { continue }
            out.append(FoodServingEntity(foodID: foodID, index: index, label: picked.quantities[index].label))
        }
        return out
    }
    func suggestedEntities() async throws -> [FoodServingEntity] { [] }  // only meaningful once a food is chosen
}
