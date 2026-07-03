// Copyright 2026 Joseph Baldwin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of
// the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
// OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
                    
                    DatePicker(selection: $selectedDate, in: ...Date(), displayedComponents: .date, label: { Text("Date") })
                    
                    Button("Save") {
                        guard calories > 0 else
                        {
                            caloriesWereNil = true
                            isFocused = true
                            return
                        }
                        Task {
                            await saveEntry()
                            dismiss()
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
        
        .onChange(of: whatItIs)
        {
            whatItIs = String(whatItIs.prefix(30))
        }
        
        .task {
            mealList = await dataStore.calorieActor.getListOfMeals()
        }
        
        .alert("Calories must be above zero.", isPresented: $caloriesWereNil) {
            Button("OK", role: .cancel) { }
        }
    }
    
    func saveEntry() async {
        await dataStore.calorieActor.updateCalories(entry: entryToEdit, calories: calories, narrative: whatItIs, date: selectedDate, meal: selectedMeal)
        await dataStore.updateLump(todayLump: todayLump)
    }
}
