//
//  FoodList.swift
//  Budgie
//
//  Created by Joe Baldwin on 26/08/2024.
//

import SwiftUI

struct FoodList: View {
    @Binding var dataObject: HealthData
    @StateObject var list: ListObject
    
    var body: some View {
        List {
            if list.budgieData.count != 0 {
                ForEach(list.mealList) { meal in
                    Section(header: Text(meal.name)) {
                        ForEach(list.budgieData) { entry in
                            if entry.meal == meal.mealUUID {
                                CalorieEntryView(calories: entry.calories, narrative: entry.narrative ?? "Quick calories", realEntry: entry.realEntry, date: entry.date)
                            }
                        }.onDelete(perform: delete)
                    }
                }
            } else {
                Text("You have no calories logged in Budgie on this day.")
            }
            
            if list.healthKitData.count != 0  {
                if list.healthKitData[0].calories != 0 {
                    Section(header: Text("Calories from other apps"), footer: Text("These are calories logged in Health by other apps. You'll need to go to the app that logged them to change or delete them.")) {
                        ForEach(list.healthKitData) {
                            CalorieEntryView(calories: $0.calories, narrative: $0.narrative ?? "Quick calories", realEntry: $0.realEntry, date: $0.date)
                        }
                    }.deleteDisabled(true)
                }
            }
        }.listStyle(.grouped)
    }
    
    func delete(at offsets: IndexSet) {
        Task {
            var toBin: [CalorieEntry] = []
            for itemId in offsets {
                toBin.append(list.budgieData[itemId])
            }
            list.budgieData.remove(atOffsets: offsets)
            await dataObject.deleteCalorieEntries(calorieObjects: toBin)
        }
    }
}

//#Preview {
//    FoodList()
//}
