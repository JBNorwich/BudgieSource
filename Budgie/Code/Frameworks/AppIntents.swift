//
//  AppIntents.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 21/03/2025.
//

import AppIntents

struct LogQuickCaloriesIntent: AppIntent {
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
        
        let snacksUUID = await dataStore.calorieActor.getMealUUIDbyName(name: "Snacks/Other")
        await dataStore.addCalories(calories: calsToLog, narrative: nil, date: Date(), meal: snacksUUID)
        
        return .result()
    }
}

struct LogFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log food"
    
    static var description = IntentDescription("Logs food to a meal in Budgie Diet.")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Calories", requestValueDialog: "The number of calories to log.")
    var calories: Int!
    
    @Parameter(title: "Food", requestValueDialog: "The name of the food eaten.")
    var narrative: String!
    
    @Parameter(title: "Meal", requestValueDialog: "The meal to log to.", optionsProvider: MealOptionsProvider())
    var meal: Meal!
    
    private struct MealOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [Meal] {
            return await dataStore.calorieActor.getListOfMeals()
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
        
        if let meal = meal {
            print("Doing nothing")
        } else {
            meal = try await $meal.requestValue(.init(stringLiteral: "What meal should this be logged to?"))
        }
        await dataStore.addCalories(calories: calsToLog, narrative: narrativeToLog, date: Date(), meal: meal.mealUUID)
        
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
                    "Log quick calories with ${applicationName}"
                ],
                shortTitle: "Log quick calories with ${applicationName}",
                systemImageName: "fork.knife"
            )
            AppShortcut(
                intent: LogWaterIntent(),
                phrases: [
                    "Log water with ${applicationName}"
                ],
                shortTitle: "Log water with ${applicationName}",
                systemImageName: "drop.fill"
            )
            AppShortcut(
                intent: LogFoodIntent(),
                phrases: [
                    "Log food with ${applicationName}"
                ],
                shortTitle: "Log food with ${applicationName}",
                systemImageName: "fork.knife"
            )
        }
}
