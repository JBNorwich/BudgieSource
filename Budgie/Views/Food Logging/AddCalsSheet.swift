//
//  AddCalsSheet.swift
//  Budgie
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
                }
            }
            
            if calories == 424242 && whatItIs == "Please help me Joe" {
                NavigationLink {
                    Tests()
                } label: {
                    Text("Debug screen")
                }
            }
            
            Button("Add calories") {
                if !String(calories ?? 0).isNumber {
                    calories = nil
                    isFocused = true
                } else {
                    if calories ?? 0 > 0 {
                        Task {
                            await HealthData().addCalories(calories: calories!, narrative: whatItIs, date: selectedDate, meal: selectedMeal)
                            isDisplayed = false
                        }
                    } else {
                        caloriesWereNil = true
                        isFocused = true
                    }
                }
            }.buttonStyle(.borderedProminent)
            Spacer()
            .navigationTitle("Add eaten calories")
        }
        
        .onAppear() {
            let calorieData = CalorieData()
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
        
        .alert("Calories can't be zero.", isPresented: $caloriesWereNil)
        {
            Button("OK", role: .cancel) { }
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
