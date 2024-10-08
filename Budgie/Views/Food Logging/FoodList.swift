//
//  FoodList.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 26/08/2024.
//

import SwiftUI

//struct FoodList: View {
//    @Binding var dataObject: HealthData
//    @StateObject var list: ListObject
//    
//    var body: some View {
//        List {
//            if list.budgieData.count != 0 {
//                ForEach(list.mealList.indices, id: \.self) { idx in
//                    Section(header: Text(list.mealList[idx].name)) {
//                        ForEach(list.budgieData.indices, id: \.self) { entryIdx in
//                            if list.budgieData[entryIdx].meal == list.mealList[idx].mealUUID {
//                                CalorieEntryView(calories: list.budgieData[entryIdx].calories, narrative: list.budgieData[entryIdx].narrative ?? "Quick calories", realEntry: list.budgieData[entryIdx].realEntry, date: list.budgieData[entryIdx].date)
//                            }
//                        }.onDelete(perform: delete)
//                    }
//                }
//            } else {
//                Text("You have no calories logged in Budgie Diet on this day.")
//            }
//            
//            if list.hkCalories != 0  {
//                Section(header: Text("Calories from other apps"), footer: Text("These are calories logged in Health by other apps. You'll need to go to the app that logged them to change or delete them.")) {
//                    CalorieEntryView(calories: list.hkCalories, narrative: "Calories from other apps", realEntry: false, date: list.curDate)
//                        .deleteDisabled(true)
//                }
//            }
//        }.listStyle(.grouped)
//    }
//    
//    func delete(at offsets: IndexSet) {
//        var toBin: [CalorieEntry] = []
//        for itemId in offsets {
//            toBin.append(list.budgieData[itemId])
//        }
//        //list.budgieData.remove(atOffsets: offsets)
//        for entry in toBin {
//            list.budgieData.removeAll(where: { $0 === entry } )
//        }
//        Task {
//            await dataObject.deleteCalorieEntries(calorieObjects: toBin)
//        }
//    }
//}

//#Preview {
//    FoodList()
//}
