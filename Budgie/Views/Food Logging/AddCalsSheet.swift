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
    enum LogMode: Hashable { case quick, savedFood }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todayLump: TodayLump

    @State private var logMode: LogMode = .quick
    @State private var showingFoodEditor = false

    // Quick-calories inputs
    @State var calories: Int?
    @State var whatItIs: String = ""
    @FocusState var isFocused: Bool
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?

    // Saved-food inputs
    @State private var selectedFoodItem: FoodItem?
    @State private var selectedQuantityIndex: Int = 0
    @State private var amount: Double = 0
    @State private var foodResults: [FoodItem] = []

    // Shared
    @State private var mealList: [Meal] = []
    @State var selectedMeal: UUID = UUID()
    var preSelectedMeal: UUID = settingsObj.snacksUUID ?? UUID()
    @State var selectedDate: Date
    @State private var showAllFoods: Bool = false
    @State private var searchText: String = ""
    @State private var displayedFoods: [CalorieEntry] = []
    @State private var reloadToken = UUID()
    @State private var reAddClone: CalorieEntry?
    

    // The calorie value that will actually be logged, whichever mode we're in.
    var effectiveCalories: Int {
        if let q = pickedQuantity { return q.totals(servings: effectiveServings).calories }
        return calories ?? 0
    }
    var pickedQuantity: FoodQuantity? {
        guard logMode == .savedFood, let item = selectedFoodItem,
              item.quantities.indices.contains(selectedQuantityIndex) else { return nil }
        return item.quantities[selectedQuantityIndex]
    }
    // The number of quantity-units eaten, derived from the amount the user typed in the food's own unit.
    var effectiveServings: Double {
        guard let q = pickedQuantity, q.count > 0 else { return 0 }
        return amount / q.count
    }
    var canSave: Bool {
        logMode == .savedFood ? (pickedQuantity != nil && effectiveServings > 0) : (calories ?? 0) > 0
    }

    var newCalsIn: Int { effectiveCalories + todayLump.eatenCalories }
    var newRemBudg: Int { todayLump.totalBudgetRem - effectiveCalories }

    // Per-meal figures — only meaningful when meal allocations are enabled.
    var selectedMealName: String {
       mealList.first(where: { $0.mealUUID == selectedMeal })?.name ?? "this meal"
   }
   var mealTarget: Int? { todayLump.mealAllocationTargets[selectedMeal] }
   var newMealRem: Int {
       (mealTarget ?? 0) - (todayLump.mealTotalList[selectedMeal] ?? 0) - effectiveCalories
   }

    // A compact protein/carbs/fat line for the live preview, empty when no macros are known.
    var macroPreview: String {
        guard let q = pickedQuantity else { return "" }
        let t = q.totals(servings: effectiveServings)
        var parts: [String] = []
        if let p = t.protein { parts.append("P \(Int(p.rounded()))g") }
        if let c = t.carbs { parts.append("C \(Int(c.rounded()))g") }
        if let f = t.fat { parts.append("F \(Int(f.rounded()))g") }
        return parts.isEmpty ? "" : "  ·  " + parts.joined(separator: " · ")
    }

    private struct FoodQueryKey: Equatable {
        var mode: LogMode
        var term: String
        var meal: UUID?          // nil == searching across all meals
        var selectedFood: UUID?  // when a food is chosen, no list load is needed
        var reload: UUID         // manual refresh trigger
    }
    private var foodQueryKey: FoodQueryKey {
        FoodQueryKey(mode: logMode,
                     term: searchText,
                     meal: showAllFoods ? nil : selectedMeal,
                     selectedFood: selectedFoodItem?.id,
                     reload: reloadToken)
    }

    var body: some View {
        Form {
            Section {
                Picker("Log mode", selection: $logMode) {
                    Text("Quick calories").tag(LogMode.quick)
                    Text("Saved food").tag(LogMode.savedFood)
                }
                .pickerStyle(.segmented)
            }

            if logMode == .quick {
                Section {
                    TextField("Calories", value: $calories, format: .number)
                        .font(.largeTitle)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                        .focused($isFocused)

                    TextField("Narrative (optional)", text: $whatItIs)

                    DisclosureGroup("Nutrition (optional)") {
                        MacroEntryFields(protein: $protein, carbs: $carbs, fat: $fat)
                    }
                }
            } else {
                Section { savedFoodContent }
            }

            Section {
                Picker("Meal", selection: $selectedMeal) {
                    ForEach(mealList) { meal in
                        Text(meal.name).tag(meal.mealUUID)
                    }
                }.pickerStyle(.menu)

                DatePicker(selection: $selectedDate, in: ...Date(), displayedComponents: .date, label: { Text("Date") })

                if Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
                    Text("This will take your total calories in today to **\(newCalsIn.formatted())** and leave you **\(abs(newRemBudg).formatted())** \(newRemBudg >= 0 ? "in" : "over") your overall budget for the rest of the day.")
                    if settingsObj.useMealAllocations, mealTarget != nil {
                       Text("It'll also leave you **\(abs(newMealRem).formatted())** \(newMealRem >= 0 ? "in" : "over") your allocation for \(selectedMealName).")
                   }
                }

                HStack {
                    Button("Log") {
                        Task {
                            await saveEntry()
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)

                    Button("Log and add more") {
                        Task {
                            await saveEntry()
                            reloadToken = UUID()
                            resetInputs()
                            isFocused = (logMode == .quick)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
            }

            if logMode == .quick {
                previousEntriesSection
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
            if logMode == .savedFood {
                guard selectedFoodItem == nil else { return }
                if searchText.isEmpty {
                    foodResults = await dataStore.foodItemActor.fetchAll()
                } else {
                    try? await Task.sleep(for: .milliseconds(200))   // debounce
                    guard !Task.isCancelled else { return }
                    foodResults = await dataStore.foodItemActor.search(term: searchText)
                }
            } else {
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
        }
        .sheet(isPresented: $showingFoodEditor) {
            NavigationStack { FoodEditorView() }
                .onDisappear { reloadToken = UUID() }   // refresh the food list after creating one
        }
        
        .navigationTitle("Add eaten calories")

        .onChange(of: whatItIs) {
            self.whatItIs = String(whatItIs.prefix(30))
        }
        .onChange(of: logMode) {
            if logMode == .quick { selectedFoodItem = nil }
            reAddClone = nil
        }
        .onChange(of: selectedFoodItem?.id) {
            selectedQuantityIndex = 0
            amount = selectedFoodItem?.quantities.first?.count ?? 0
        }
        .onChange(of: selectedQuantityIndex) {
            amount = pickedQuantity?.count ?? amount
        }

        .task {
            mealList = (await dataStore.calorieActor.getListOfMeals()).sorted { $0.order < $1.order }
            // Use the pre-selected meal if it maps to a real meal, otherwise fall back to the first.
            guard let startingMeal = mealList.first(where: { $0.mealUUID == preSelectedMeal }) ?? mealList.first else { return }
            selectedMeal = startingMeal.mealUUID
        }
    }

    // MARK: - Saved-food mode content

    @ViewBuilder
    var savedFoodContent: some View {
        if let item = selectedFoodItem {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name).font(.headline)
                    if let m = item.manufacturer, !m.isEmpty {
                        Text(m).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Change") { selectedFoodItem = nil }
                    .buttonStyle(.borderless)
            }

            if item.quantities.isEmpty {
                Text("This food has no servings set yet.").foregroundStyle(.secondary)
            } else {
                if item.quantities.count > 1 {
                    Picker("Serving", selection: $selectedQuantityIndex) {
                        ForEach(item.quantities.indices, id: \.self) { i in
                            Text(item.quantities[i].label).tag(i)
                        }
                    }.pickerStyle(.menu)
                }

                if let q = pickedQuantity {
                    HStack {
                        Text(q.type == .portion ? "Portions" : "Amount")
                        Spacer()
                        TextField("", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        if q.type != .portion { Text(q.type.unitName) }
                    }
                    Text("**\(effectiveCalories.formatted())** kcal\(macroPreview)")
                }
            }
        } else {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search your foods", text: $searchText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
            }
            
            Button {
                showingFoodEditor = true
            } label: {
                Label("Create a new food", systemImage: "plus.circle")
            }
            
            if foodResults.isEmpty {
                Text(searchText.isEmpty ? "You haven't saved any foods yet." : "No foods match your search.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(foodResults) { item in
                    Button {
                        selectedFoodItem = item
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                if let m = item.manufacturer, !m.isEmpty {
                                    Text(m).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if let first = item.quantities.first {
                                Text("\(first.calories.formatted()) kcal").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Quick-mode "previous entries" prefill

    @ViewBuilder
    var previousEntriesSection: some View {
        Section(header: Text("Previous entries")) {
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
                        reAddClone = entry.isFoodEntry ? entry : nil
                    }
                }
            }
        }
    }

    // MARK: - Persistence

    func saveEntry() async {
        if logMode == .savedFood, let item = selectedFoodItem, let q = pickedQuantity {
            await dataStore.addFoodEntry(foodItemID: item.id, name: item.name,
                                         manufacturer: item.manufacturer,
                                         quantity: q, servings: effectiveServings,
                                         date: selectedDate, meal: selectedMeal)
        } else if let clone = reAddClone, (calories ?? 0) == clone.calories {
            // Re-adding a previous food entry, untouched — keep its serving, macros and food link.
            await dataStore.calorieActor.reAddEntry(from: clone, date: selectedDate, meal: selectedMeal)
        } else {
            await dataStore.addCalories(calories: calories!, narrative: whatItIs,
                                        date: selectedDate, meal: selectedMeal,
                                        protein: protein, fat: fat, carbs: carbs)
        }
        await dataStore.updateLump(todayLump: todayLump)
    }

    func resetInputs() {
        calories = nil
        whatItIs = ""
        protein = nil
        carbs = nil
        fat = nil
        selectedFoodItem = nil
        selectedQuantityIndex = 0
        amount = 0
        reAddClone = nil
    }
}

#Preview {
    NavigationStack {
        AddCalsSheet(selectedDate: Date()).environmentObject(TodayLump())
    }
}
