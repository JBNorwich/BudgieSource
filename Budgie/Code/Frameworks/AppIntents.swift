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
    func perform() async throws -> some IntentResult {
        var calsToLog: Int
        
        if let calories = calories {
            calsToLog = calories
        } else {
            calsToLog = try await $calories.requestValue(.init(stringLiteral: "How many calories did you eat?"))
        }
        
        // Right now there's no more graceful means of knowing what the UUID is for "Snacks/Other" other than this.
        // I'm going to try and put something more elegant in for this in the future, but right now, this works.
        let snacksUUID = await dataStore.calorieActor.getMealUUIDbyName(name: "Snacks/Other")
        await dataStore.addCalories(calories: calsToLog, narrative: nil, date: Date(), meal: snacksUUID)
        
        return .result()
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
    
    @MainActor func perform() async throws -> some IntentResult {
        var calsToLog: Int
        var narrativeToLog: String
        
        if let calories = calories {
            calsToLog = calories
        } else {
            calsToLog = try await $calories.requestValue(.init(stringLiteral: "How many calories did you eat?"))
        }
        
        if let narrative = narrative {
            narrativeToLog = narrative
        } else {
            narrativeToLog = try await $narrative.requestValue(.init(stringLiteral: "What did you eat?"))
        }
        
        if meal == nil {
            meal = try await $meal.requestValue(.init(stringLiteral: "What meal should this be logged to?"))
        }
        
        await dataStore.addCalories(calories: calsToLog, narrative: narrativeToLog, date: Date(), meal: meal.id)
        
        return .result()
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
    func perform() async throws -> some IntentResult {
        var mlsToLog: Int
        
        if let millilitres = millilitres {
            mlsToLog = millilitres
        } else {
            mlsToLog = try await $millilitres.requestValue(.init(stringLiteral: "How much water did you drink, in millilitres?"))
        }
        
        await dataStore.addWater(amount: mlsToLog, datetime: Date())
        
        return .result()
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
        }
}
