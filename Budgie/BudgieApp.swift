//
//  BudgieApp.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 19/08/2024.
//

import SwiftUI
import HealthKitUI

let healthStore: HKHealthStore = HKHealthStore()
let settingsObj: UserSettings = UserSettings()
let dataStore: HealthData = HealthData()

@main
struct BudgieApp: App {
    init() {
        Task {
            if await dataStore.calorieActor.getListOfMeals() == [] {
                await dataStore.calorieActor.setUpMeals()
            }
            if await dataStore.settingsActor.getSettingObject(name: "settingsReady") == nil {
                await dataStore.settingsActor.createSettings()
            }
        }
        pingSettingsToWatch()
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack() {
                BudgetView()
            }
        }
    }
}
