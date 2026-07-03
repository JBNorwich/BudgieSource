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

struct AddCalsSheet: View {
    @Binding var isDisplayed: Bool
    @EnvironmentObject var todayLump: TodayLump
    @State var calories: Int?
    @State var caloriesWereNil: Bool = false
    @State var whatItIs: String = ""
    @FocusState var isFocused: Bool
    @State private var mealList: [Meal] = []
    @State var selectedMeal: UUID = UUID()
    var preSelectedMeal: UUID = settingsObj.snacksUUID ?? UUID()
    @State var selectedDate: Date
    @State private var showAllFoods: Bool = false
    @State private var searchText: String = ""
    
    @State private var displayedFoods: [CalorieEntry] = []
    @State private var reloadToken = UUID()
    
    var newCalsIn: Int { (calories ?? 0) + todayLump.eatenCalories }
    var newRemBudg: Int { todayLump.totalBudgetRem - (calories ?? 0) }
    
    // Per-meal figures — only meaningful when meal allocations are enabled.
    var selectedMealName: String {
       mealList.first(where: { $0.mealUUID == selectedMeal })?.name ?? "this meal"
   }
   var mealTarget: Int? { todayLump.mealAllocationTargets[selectedMeal] }
   var newMealRem: Int {
       (mealTarget ?? 0) - (todayLump.mealTotalList[selectedMeal] ?? 0) - (calories ?? 0)
   }
    
    private struct FoodQueryKey: Equatable {
        var term: String
        var meal: UUID?      // nil == searching across all meals
        var reload: UUID     // manual refresh trigger (see below)
    }
    private var foodQueryKey: FoodQueryKey {
        FoodQueryKey(term: searchText,
                     meal: showAllFoods ? nil : selectedMeal,
                     reload: reloadToken)
    }
        
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
                        ForEach(mealList) { meal in
                            Text(meal.name)
                                .tag(meal.mealUUID)
                        }
                    }.pickerStyle(.menu)
                    
                    DatePicker(selection: $selectedDate, displayedComponents: .date, label: { Text("Date") })
                    
                    if (getMidnightOnDayBefore(date: Date()) == getMidnightOnDayBefore(date: selectedDate))
                    {
                        Text("This will take your total calories in today to **\(newCalsIn.formatted())** and leave you **\(abs(newRemBudg).formatted())** \(newRemBudg > 0 ? "in" : "over") your overall budget for the rest of the day.")
                        if settingsObj.useMealAllocations, mealTarget != nil {
                           Text("It'll also leave you **\(abs(newMealRem).formatted())** \(newMealRem > 0 ? "in" : "over") your allocation for \(selectedMealName).")
                       }
                    }
                    
                    HStack {
                        Button("Save") {
                            guard (calories ?? 0) > 0 else
                            {
                                caloriesWereNil = true
                                isFocused = true
                                return
                            }
                            Task {
                                await saveEntry()
                                isDisplayed = false
                            }
                        }.buttonStyle(.borderedProminent)
                        
                        Button("Save and add more") {
                            guard (calories ?? 0) > 0 else
                            {
                                caloriesWereNil = true
                                isFocused = true
                                return
                            }
                            Task {
                                await saveEntry()
                                reloadToken = UUID()
                                calories = nil
                                whatItIs = ""
                                isFocused = true
                            }
                        }.buttonStyle(.borderedProminent)
                    }
                }
                
                Section(header: Text("Previous entries")) {
                    // Search box
                    HStack {
                        Image(systemName: "magnifyingglass")
                        
                        TextField("Search", text: $searchText)
                            .foregroundColor(.primary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                    }
                    Picker("Label", selection: $showAllFoods) {
                            Text("Current meal").tag(false)
                            Text("All meals").tag(true)
                    }.pickerStyle(.segmented)
                    
                    List {
                        ForEach(displayedFoods) { entry in
                            HStack {
                                Text(entry.narrative ?? "Quick calories")
                                Spacer()
                                Text(entry.calories.formatted())
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                whatItIs = entry.narrative ?? "Quick calories"
                                calories = entry.calories
                            }
                        }
                    }
                }
                    
                if calories == 424242 && whatItIs.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("please help me joe") == .orderedSame {
                    NavigationLink {
                        Tests()
                    } label: {
                        Text("Debug screen")
                    }
                }
            }
            .task(id: foodQueryKey) {
                if searchText.isEmpty {
                    let scopeMeal = showAllFoods ? nil : mealList.first { $0.mealUUID == selectedMeal }
                    displayedFoods = await dataStore.calorieActor.fetchCalsForMeal(scopeMeal)
                } else {
                    try? await Task.sleep(for: .milliseconds(200))   // debounce
                    guard !Task.isCancelled else { return }
                    displayedFoods = await dataStore.calorieActor.searchCals(
                        term: searchText,
                        meal: showAllFoods ? nil : selectedMeal
                    )
                }
            }
            
            .navigationTitle("Add eaten calories")
        }
        
        .onChange(of: whatItIs) {
            self.whatItIs = String(whatItIs.prefix(30))
        }
        
        .alert("Calories can't be zero.", isPresented: $caloriesWereNil)
        {
            Button("OK", role: .cancel) { }
        }
        
        .task {
            mealList = (await dataStore.calorieActor.getListOfMeals()).sorted { $0.order < $1.order }
            // Use the pre-selected meal if it maps to a real meal, otherwise fall back to the first.
            guard let startingMeal = mealList.first(where: { $0.mealUUID == preSelectedMeal }) ?? mealList.first else { return }
            selectedMeal = startingMeal.mealUUID
        }
    }
    
    func saveEntry() async {
        await dataStore.addCalories(calories: calories!, narrative: whatItIs, date: selectedDate, meal: selectedMeal)
        await dataStore.updateLump(todayLump: todayLump)
    }
}

#Preview {
    struct Preview: View {
        @State var presented = true
        
        var body: some View {
            AddCalsSheet(isDisplayed:$presented, selectedDate: Date()).environmentObject(TodayLump())
        }
    }
    return Preview()
}
