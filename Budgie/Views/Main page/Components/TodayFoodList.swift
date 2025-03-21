//
//  TodayFoodList.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 28/08/2024.
//

import SwiftUI

struct TodayFoodList: View {
    @Environment(\.defaultMinListRowHeight) var minRowHeight
    
    @EnvironmentObject var dataLump: TodayLump
    @State var firstRow = true
    
    var body: some View {
        Spacer()
        if dataLump.foodList.count != 0 || dataLump.healthKitCalories != 0 {
            if dataLump.foodList.count != 0 {
                ForEach(dataLump.mealList) { meal in
                    HStack {
                        Text(meal.name.uppercased())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if dataLump.mealList.first == meal {
                            Text("CALORIES")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(dataLump.foodList) { entry in
                        if entry.meal == meal.mealUUID {
                            CalorieEntryView(calories: entry.calories, narrative: entry.narrative ?? "Quick calories", realEntry: entry.realEntry, date: entry.date)
                        }
                    }
                    Spacer()
                }
            }
            
            if dataLump.healthKitCalories != 0 && settingsObj.manualMode == false {
                Spacer()
                HStack {
                    Text("FROM OTHER APPS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                        Text("CALORIES")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                }
                CalorieEntryView(calories: dataLump.healthKitCalories, narrative: "Calories from Apple Health", realEntry: false, date: getStartOfDay(date: Date()))
                Spacer()
            }
        } else {
            Text("You have no eaten calories logged today.")
        }
    }
}

//#Preview {
//    TodayFoodList()
//}
