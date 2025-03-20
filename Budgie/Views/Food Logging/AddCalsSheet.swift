//
//  AddCalsSheet.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 22/08/2024.
//

import SwiftUI

extension String {
    var isNumber: Bool {
        return self.allSatisfy { character in
            character.isNumber
        }
    }
}

struct AddCalsSheet: View {
    @Binding var dataStore: HealthData
    @Binding var isDisplayed: Bool
    
    var curEaten: Int = 0
    var remBudg: Int = 0
    
    @State var calorieData: CalorieData = CalorieData()
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
    @State private var showAllFoods: Bool = false
    
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
                               in: ...getMidnightOnDayAfter(date: Date()),
                               label: {
                        Text("Date and time")
                    }
                    )
                    
                    if (newRemBudg > 0)
                    {
                        Text("This will take your total calories in today to **\(newCalsIn.formatted())** and leave you **\(newRemBudg.formatted())** in your overall budget for the rest of the day.")
                    } else {
                        Text("This will take your total calories in today to **\(newCalsIn.formatted())** and leave you **\((-newRemBudg).formatted())** over your overall budget for the rest of the day.")
                    }
                    
                    HStack {
                        Button("Save") {
                            if !String(calories ?? 0).isNumber {
                                calories = nil
                                isFocused = true
                            } else {
                                if calories ?? 0 > 0 {
                                    Task {
                                        await dataStore.addCalories(calories: calories!, narrative: whatItIs, date: selectedDate, meal: selectedMeal)
                                        print("Adding calories")
                                        isDisplayed = false
                                    }
                                } else {
                                    caloriesWereNil = true
                                    isFocused = true
                                }
                            }
                        }.buttonStyle(.borderedProminent)
                        
                        Button("Save and add more") {
                            if !String(calories ?? 0).isNumber {
                                calories = nil
                                isFocused = true
                            } else {
                                if calories ?? 0 > 0 {
                                    Task {
                                        await dataStore.addCalories(calories: calories!, narrative: whatItIs, date: selectedDate, meal: selectedMeal)
                                        print("Adding calories")
                                        if showAllFoods == true {
                                            Task {
                                                prevFoods = await calorieData.fetchCalsForMeal(nil)
                                            }
                                        } else {
                                            let mealWithUUID = mealList.first(where: { $0.mealUUID == selectedMeal })!
                                            Task {
                                                prevFoods = await calorieData.fetchCalsForMeal(mealWithUUID)
                                            }
                                        }
                                        calories = nil
                                        whatItIs = ""
                                        isFocused = true
                                    }
                                } else {
                                    caloriesWereNil = true
                                    isFocused = true
                                }
                            }
                        }.buttonStyle(.borderedProminent)
                    }
                }
                    
                Section(header: Text("Previous entries")) {
                    Picker("Label", selection: $showAllFoods) {
                            Text("Current meal").tag(false)
                            Text("All meals").tag(true)
                    }.pickerStyle(.segmented)
                    
                    List {
                        ForEach(prevFoods) { entry in
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
            mealList = calorieData.getListOfMeals()
            mealList = mealList.sorted(by: { $0.order < $1.order })
            selectedMeal = mealList.first!.mealUUID
            
        }
        
        .onChange(of: calories)
        {
            newCalsIn = (calories ?? 0) + curEaten
            newRemBudg = remBudg - (calories ?? 0)
        }
        
        .onChange(of: whatItIs) {
            self.whatItIs = String(whatItIs.prefix(30))
        }
        
        .onChange(of: selectedMeal) {
            if showAllFoods != true {
                let mealWithUUID = mealList.first(where: { $0.mealUUID == selectedMeal })!
                Task {
                    prevFoods = await calorieData.fetchCalsForMeal(mealWithUUID)
                }
            }
        }
        
        .onChange(of: showAllFoods) {
            if showAllFoods == true {
                Task {
                    prevFoods = await calorieData.fetchCalsForMeal(nil)
                }
            } else {
                let mealWithUUID = mealList.first(where: { $0.mealUUID == selectedMeal })!
                Task {
                    prevFoods = await calorieData.fetchCalsForMeal(mealWithUUID)
                }
            }
        }
        
        .alert("Calories can't be zero.", isPresented: $caloriesWereNil)
        {
            Button("OK", role: .cancel) { }
        }
        
        .task {
            prevFoods = await calorieData.fetchCalsForMeal(mealList.first!)
        }
    }
}

#Preview {
    struct Preview: View {
        @State var presented = true
        @State var data = HealthData()
        
        var body: some View {
            AddCalsSheet(dataStore: $data, isDisplayed:$presented, selectedDate: Date())
        }
    }
    return Preview()
}
