//
//  FoodList.swift
//  Budgie
//
//  Created by Joe Baldwin on 26/08/2024.
//

import SwiftUI

struct FoodList: View {
    @Binding var dataObject: HealthData
    @State var mealList: [Meal] = []
    @Binding var displayedData: [CalorieEntry]
    @Binding var healthKitData: [CalorieEntry]
    
    var body: some View {
        List {
            if displayedData.count != 0 {
                ForEach(mealList) { meal in
                    Section(header: Text(meal.name)) {
                        ForEach(displayedData) { entry in
                            if entry.meal == meal.mealUUID {
                                CalorieEntryView(calories: entry.calories, narrative: entry.narrative ?? "Quick calories", realEntry: entry.realEntry, date: entry.date)
                            }
                        }.onDelete(perform: delete)
                    }
                }
            } else {
                Text("You have no calories logged in Budgie on this day.")
            }
            
            if healthKitData.count != 0  {
                if healthKitData[0].calories != 0 {
                    Section(header: Text("Calories from other apps")) {
                        ForEach(healthKitData) {
                            CalorieEntryView(calories: $0.calories, narrative: $0.narrative ?? "Quick calories", realEntry: $0.realEntry, date: $0.date)
                        }
                        Text("These are calories logged in Health by other apps. You'll need to go to the app that logged them to change or delete them.")
                            .foregroundStyle(.secondary)
                    }.deleteDisabled(true)
                }
            }
        }.listStyle(.grouped)
            //.listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        
        .onAppear {
            let calorieData = CalorieData()
            mealList = calorieData.cleansedMealList(data: displayedData)
        }
    }
    
    func delete(at offsets: IndexSet) {
        Task {
            var toBin: [CalorieEntry] = []
            for itemId in offsets {
                toBin.append(displayedData[itemId])
            }
            print(toBin.count.formatted())
            displayedData.remove(atOffsets: offsets)
            await dataObject.deleteCalorieEntries(calorieObjects: toBin)
        }
    }
}

//#Preview {
//    FoodList()
//}
