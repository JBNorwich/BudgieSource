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

extension String {
    var isNumber: Bool {
        return self.allSatisfy { character in
            character.isNumber || character.isMathSymbol
        }
    }
}

struct AddCalsSheet: View {
    @Binding var isDisplayed: Bool
    @EnvironmentObject var todayLump: TodayLump
    @State var fieldString: String = "0"
    @State var calories: Int?
    @State var newCalsIn: Int = 0
    @State var newRemBudg: Int = 0
    @State var caloriesWereNil: Bool = false
    @State var whatItIs: String = ""
    @FocusState var isFocused: Bool
    @State private var mealList: [Meal] = []
    @State var selectedMeal: UUID = UUID()
    @State var selectedDate: Date
    @State var prevFoods: [CalorieEntry] = []
    @State var displayedFoods: [CalorieEntry] = []
    @State private var showAllFoods: Bool = false
    @State private var searchText: String = ""
    @State private var showCancelButton: Bool = false
        
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
                    
                    DatePicker(selection: $selectedDate,
                        label: {
                            Text("Date and time")
                        }
                    )
                    
                    if (getMidnightOnDayBefore(date: Date()) == getMidnightOnDayBefore(date: selectedDate))
                    {
                        if newRemBudg > 0 {
                            Text("This will take your total calories in today to **\(newCalsIn.formatted())** and leave you **\(newRemBudg.formatted())** in your overall budget for the rest of the day.")
                        } else {
                            Text("This will take your total calories in today to **\(newCalsIn.formatted())** and leave you **\((-newRemBudg).formatted())** over your overall budget for the rest of the day.")
                        }
                    }
                    
                    HStack {
                        Button("Save") {
                            if caloriesValid() == true {
                                Task {
                                    await dataStore.addCalories(calories: calories!, narrative: whatItIs, date: selectedDate, meal: selectedMeal)
                                    isDisplayed = false
                                    Task {
                                        await dataStore.updateLump(todayLump: todayLump)
                                    }
                                }
                            } else {
                                caloriesWereNil = true
                                isFocused = true
                            }
                        }.buttonStyle(.borderedProminent)
                        
                        Button("Save and add more") {
                            if caloriesValid() == true {
                                Task {
                                    await dataStore.addCalories(calories: calories!, narrative: whatItIs, date: selectedDate, meal: selectedMeal)
                                    print("Adding calories")
                                    doUpdates()
                                    Task {
                                        await dataStore.updateLump(todayLump: todayLump)
                                    }
                                    calories = nil
                                    whatItIs = ""
                                    isFocused = true
                                }
                            } else {
                                caloriesWereNil = true
                                isFocused = true
                            }
                        }.buttonStyle(.borderedProminent)
                    }
                }
                
                Section(header: Text("Previous entries")) {
                    // Search box
                    HStack {
                        Image(systemName: "magnifyingglass")
                        
                        TextField("Search", text: $searchText, onEditingChanged: { isEditing in
                            self.showCancelButton = true
                        })
                            .foregroundColor(.primary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        
                        Button(action: {
                            self.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill").opacity(searchText == "" ? 0 : 1)
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
                    
                if calories == 424242 && whatItIs == "Please help me Joe" {
                    NavigationLink {
                        Tests()
                    } label: {
                        Text("Debug screen")
                    }
                }
            }
            
            .navigationTitle("Add eaten calories")
        }
        
        .onAppear() {
            newCalsIn = todayLump.eatenCalories
            newRemBudg = todayLump.totalBudgetRem
        }
        
        .onChange(of: calories)
        {
            newCalsIn = (calories ?? 0) + todayLump.eatenCalories
            newRemBudg = todayLump.totalBudgetRem - (calories ?? 0)
        }
        
        .onChange(of: whatItIs) {
            self.whatItIs = String(whatItIs.prefix(30))
        }
        
        .onChange(of: selectedMeal) {
            doUpdates()
        }
        
        .onChange(of: showAllFoods) {
            doUpdates()
        }
        
        .onChange(of: searchText) {
            doUpdates()
        }
        
        .alert("Calories can't be zero.", isPresented: $caloriesWereNil)
        {
            Button("OK", role: .cancel) { }
        }
        
        .task {
            mealList = await dataStore.calorieActor.getListOfMeals()
            mealList = mealList.sorted(by: { $0.order < $1.order })
            selectedMeal = mealList.first!.mealUUID
            prevFoods = await dataStore.calorieActor.fetchCalsForMeal(mealList.first!)
        }
    }
    
    func doUpdates() {
        if showAllFoods == true {
            Task {
                prevFoods = await dataStore.calorieActor.fetchCalsForMeal(nil)
            }
        } else {
            let mealWithUUID = mealList.first(where: { $0.mealUUID == selectedMeal })!
            Task {
                prevFoods = await dataStore.calorieActor.fetchCalsForMeal(mealWithUUID)
            }
        }
        if searchText != "" {
            displayedFoods = prevFoods.filter {
                $0.narrative != nil && $0.narrative!.lowercased().contains(searchText.lowercased())
            }
        } else {
            displayedFoods = prevFoods
        }
    }
    
    func caloriesValid() -> Bool {
        if !String(calories ?? 0).isNumber {
            return false
        } else {
            if calories ?? 0 > 0 {
                return true
            } else {
                return false
            }
        }
    }
}

#Preview {
    struct Preview: View {
        @State var presented = true
        @State var data = HealthData()
        
        var body: some View {
            AddCalsSheet(isDisplayed:$presented, selectedDate: Date()).environmentObject(TodayLump())
        }
    }
    return Preview()
}
