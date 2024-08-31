//
//  BudgieApp.swift
//  Budgie
//
//  Created by Joe Baldwin on 19/08/2024.
//

import SwiftUI
import HealthKitUI

let healthStore: HKHealthStore = HKHealthStore()
let settingsObj: UserSettings = UserSettings()



@main
struct BudgieApp: App {
    
    init() {
        let mealStore = CalorieData()
        if mealStore.getListOfMeals() == [] {
            mealStore.setUpMeals()
        }
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack() {
                BudgetView()
            }
        }
    }
}
