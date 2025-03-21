//
//  BudgieWatchApp.swift
//  BudgieWatch Watch App
//
//  Created by Joe Baldwin on 01/09/2024.
//

import SwiftUI
import HealthKitUI

let settingsObj = UserSettings()
let healthStore = HKHealthStore()
let dataStore = HealthData()

@main
struct BudgieWatch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
