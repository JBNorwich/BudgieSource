//
//  AppIntents.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 21/03/2025.
//

import AppIntents

struct LogQuickCaloriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Log quick calories"
    
    static var description = IntentDescription("Logs food to Budgie Diet.")
    
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

struct LogFoodShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
        static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: LogQuickCaloriesIntent(),
                phrases: [
                    "Log quick calories"
                ],
                shortTitle: "Log quick calories",
                systemImageName: "fork.knife"
            )
        }
}
