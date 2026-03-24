//
//  BudgieApp.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 19/08/2024.
//

import SwiftUI
import HealthKitUI

let healthStore: HKHealthStore = HKHealthStore()
//let settingsObj: UserSettings = UserSettings()
let settingsObj: CloudSettings = CloudSettings()
let localSettings: UserSettings = UserSettings()
let dataStore: HealthData = HealthData()

@main
struct BudgieApp: App {
    init() {
        settingsObj.sync()
        Task {
            if await dataStore.calorieActor.getListOfMeals() == [] {
                await dataStore.calorieActor.setUpMeals()
            }
        }
        if settingsObj.onCloud == false {
            // cloud sync not done
            if localSettings.isFirstRun == false {
                // user's settings need to be moved to cloud
                settingsObj.copyFromLocal(localObj: localSettings)
            } else {
                // user's settings were never saved locally
                localSettings.onCloud = true
                settingsObj.onCloud = true
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
