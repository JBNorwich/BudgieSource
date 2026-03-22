//
//  EditCalsSheet.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 22/03/2026.
//

import SwiftUI

struct EditCalsSheet: View {
    @EnvironmentObject var todayLump: TodayLump
    @Environment(\.dismiss) private var dismiss
    var entryToEdit: CalorieEntry
    @FocusState var isFocused: Bool
    @State private var calories: Int = 0
    @State private var whatItIs: String = ""
    @State private var selectedMeal: UUID = UUID()
    @State private var selectedDate: Date = Date()
    @State private var caloriesWereNil: Bool = false
    @State private var mealList: [Meal] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Calories", value: $calories, format: .number)
                        .font(.largeTitle)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                    
                    TextField("Narrative (optional)", text: $whatItIs)
                    
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(mealList.sorted(by: {$0.order < $1.order})) { meal in
                            Text(meal.name)
                                .tag(meal.mealUUID)
                        }
                    }.pickerStyle(.menu)
                    
                    DatePicker(selection: $selectedDate,
                        label: {
                            Text("Date and time")
                        }
                    )
                    
                    Button("Save") {
                        if !String(calories).isNumber {
                            calories = 0
                            isFocused = true
                        } else {
                            if calories > 0 {
                                Task {
                                    await dataStore.calorieActor.deleteEntries(objects: [entryToEdit])
                                    await dataStore.addCalories(calories: calories, narrative: whatItIs, date: selectedDate, meal: selectedMeal)
                                    await dataStore.updateLump(todayLump: todayLump)
                                }
                                dismiss()
                            } else {
                                caloriesWereNil = true
                                isFocused = true
                            }
                        }
                    }.buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Edit food entry")
        .onAppear {
            calories = entryToEdit.calories
            whatItIs = entryToEdit.narrative ?? "Quick calories"
            selectedDate = entryToEdit.date
            selectedMeal = entryToEdit.meal
        }
    }
}
