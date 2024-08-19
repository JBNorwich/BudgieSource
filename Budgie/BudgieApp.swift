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
        print("Checking to see if meal store is populated...")
        let mealStore = CalorieData()
        if mealStore.getListOfMeals() == [] {
            print("No meals. Setting up")
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
