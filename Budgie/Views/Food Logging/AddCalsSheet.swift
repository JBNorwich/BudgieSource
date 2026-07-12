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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todayLump: TodayLump

    // MARK: Manual entry
    @State var calories: Int?
    @State var whatItIs: String = ""
    @State private var manufacturer: String = ""
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var alsoSave: Bool = false
    @State private var saveServingUnit: FoodQuantityType = .portion
    @State private var saveServingCount: Double = 1
    @FocusState private var caloriesFocused: Bool

    // MARK: Food selection (scaling an existing food)
    @State private var selectedFood: PickedFood?
    @State private var selectedQuantityIndex: Int = 0
    @State private var amount: Double = 0

    // MARK: Re-add of a past entry (preserves link/macros if logged unchanged)
    @State private var reAddClone: CalorieEntry?

    // MARK: Search
    @State private var searchText: String = ""
    @State private var foodResults: [PickedFood] = []
    @State private var entryResults: [CalorieEntry] = []
    @State private var showAllFoods: Bool = false
    @State private var displayedFoods: [CalorieEntry] = []
    @State private var showingOFFSheet = false

    // MARK: Shared
    @State private var mealList: [Meal] = []
    @State var selectedMeal: UUID = UUID()
    var preSelectedMeal: UUID = settingsObj.snacksUUID ?? UUID()
    @State var selectedDate: Date
    @State private var reloadToken = UUID()

    // MARK: Derived
    private var pickedQuantity: FoodQuantity? {
        guard let food = selectedFood, food.quantities.indices.contains(selectedQuantityIndex) else { return nil }
        return food.quantities[selectedQuantityIndex]
    }
    private var effectiveServings: Double {
        guard let q = pickedQuantity, q.count > 0 else { return 0 }
        return amount / q.count
    }
    private var effectiveCalories: Int {
        if let q = pickedQuantity { return q.totals(servings: effectiveServings).calories }
        return calories ?? 0
    }
    private var canSave: Bool {
        if selectedFood != nil { return pickedQuantity != nil && effectiveServings > 0 }
        if alsoSave { return (calories ?? 0) > 0 && !whatItIs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return (calories ?? 0) > 0
    }

    private var newCalsIn: Int { effectiveCalories + todayLump.eatenCalories }
    private var newRemBudg: Int { todayLump.totalBudgetRem - effectiveCalories }
    private var selectedMealName: String {
        mealList.first(where: { $0.mealUUID == selectedMeal })?.name ?? "this meal"
    }
    private var mealTarget: Int? { todayLump.mealAllocationTargets[selectedMeal] }
    private var newMealRem: Int {
        (mealTarget ?? 0) - (todayLump.mealTotalList[selectedMeal] ?? 0) - effectiveCalories
    }
    private var scaledMacroPreview: String {
        guard let q = pickedQuantity else { return "" }
        let t = q.totals(servings: effectiveServings)
        var parts: [String] = []
        if let p = t.protein { parts.append("P \(Int(p.rounded()))g") }
        if let c = t.carbs { parts.append("C \(Int(c.rounded()))g") }
        if let f = t.fat { parts.append("F \(Int(f.rounded()))g") }
        return parts.isEmpty ? "" : "  ·  " + parts.joined(separator: " · ")
    }

    private struct SearchKey: Equatable {
        var term: String
        var allMeals: Bool
        var meal: UUID
        var reload: UUID
    }
    private var searchKey: SearchKey {
        SearchKey(term: searchText, allMeals: showAllFoods, meal: selectedMeal, reload: reloadToken)
    }

    // MARK: Body

    var body: some View {
        Group {
            if searchText.isEmpty {
                loggingForm
            } else {
                searchResults
            }
        }
        .searchable(text: $searchText, prompt: "Search foods and past entries")
        .sheet(isPresented: $showingOFFSheet) {
            OpenFoodFactsSheet(term: searchText) { food in
                selectFood(food)          // import → select into the form (step 2 fills this in)
                showingOFFSheet = false
            }
        }
        .navigationTitle("Add food")
        .task(id: searchKey) {
            if searchText.isEmpty {
                let scope = showAllFoods ? nil : mealList.first { $0.mealUUID == selectedMeal }
                displayedFoods = await dataStore.calorieActor.fetchCalsForMeal(scope)
                foodResults = []
                entryResults = []
            } else {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                let mine = await dataStore.foodItemActor.search(term: searchText)
                let generic = FoodCatalogue.shared.search(searchText)
                foodResults = mine.map(\.asPicked) + generic.map(\.asPicked)
                let entries = await dataStore.calorieActor.searchCals(term: searchText, meal: nil)
                entryResults = entries.filter { $0.foodItem == nil }   // only unlinked → "Quick entries"
            }
        }
        .onChange(of: whatItIs) { whatItIs = String(whatItIs.prefix(30)) }
        .task {
            mealList = (await dataStore.calorieActor.getListOfMeals()).sorted { $0.order < $1.order }
            guard let start = mealList.first(where: { $0.mealUUID == preSelectedMeal }) ?? mealList.first else { return }
            selectedMeal = start.mealUUID
        }
    }

    // MARK: Logging form (shown when not searching)

    @ViewBuilder
    private var loggingForm: some View {
        Form {
            if let food = selectedFood {
                Section { scalingContent(food) }
            } else {
                Section { manualContent }
            }

            Section {
                Picker("Meal", selection: $selectedMeal) {
                    ForEach(mealList) { meal in Text(meal.name).tag(meal.mealUUID) }
                }.pickerStyle(.menu)

                DatePicker(selection: $selectedDate, in: ...Date(), displayedComponents: .date) { Text("Date") }

                if Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
                    Text("This will take your total calories in today to **\(newCalsIn.formatted())** and leave you **\(abs(newRemBudg).formatted())** \(newRemBudg >= 0 ? "in" : "over") your overall budget for the rest of the day.")
                    if settingsObj.useMealAllocations, mealTarget != nil {
                        Text("It'll also leave you **\(abs(newMealRem).formatted())** \(newMealRem >= 0 ? "in" : "over") your allocation for \(selectedMealName).")
                    }
                }

                HStack {
                    Button("Log") {
                        Task { await saveEntry(); dismiss() }
                    }.buttonStyle(.borderedProminent).disabled(!canSave)

                    Button("Log and add more") {
                        Task {
                            await saveEntry()
                            reloadToken = UUID()
                            resetInputs()
                            caloriesFocused = true
                        }
                    }.buttonStyle(.borderedProminent).disabled(!canSave)
                }
            }
            
            if selectedFood == nil {
                previousEntriesSection
            }
        }
    }

    @ViewBuilder
    private var manualContent: some View {
        TextField("Calories", value: $calories, format: .number)
            .font(.largeTitle)
            .keyboardType(.numberPad)
            .autocorrectionDisabled()
            .focused($caloriesFocused)

        TextField("Name (optional)", text: $whatItIs)
        TextField("Manufacturer (optional)", text: $manufacturer)

        DisclosureGroup("Nutrition (optional)") {
            MacroEntryFields(protein: $protein, carbs: $carbs, fat: $fat)
        }

        Toggle("Also save to my foods", isOn: $alsoSave)

        if alsoSave {
            Picker("Measured in", selection: $saveServingUnit) {
                Text("Portion").tag(FoodQuantityType.portion)
                Text("Grams").tag(FoodQuantityType.grams)
                Text("Millilitres").tag(FoodQuantityType.millilitres)
            }.pickerStyle(.menu)

            HStack {
                Text(saveServingUnit == .portion ? "Servings" : "Amount")
                Spacer()
                TextField("", value: $saveServingCount, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                if saveServingUnit != .portion { Text(saveServingUnit.unitName) }
            }
        }
    }

    @ViewBuilder
    private func scalingContent(_ food: PickedFood) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(food.name).font(.headline)
                if let m = food.manufacturer, !m.isEmpty {
                    Text(m).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Change") { selectedFood = nil }.buttonStyle(.borderless)
        }

        if food.quantities.count > 1 {
            Picker("Serving", selection: $selectedQuantityIndex) {
                ForEach(food.quantities.indices, id: \.self) { i in
                    Text(food.quantities[i].label).tag(i)
                }
            }.pickerStyle(.menu)
        }

        if let q = pickedQuantity {
            HStack {
                Text(q.type == .portion ? "Portions" : "Amount")
                Spacer()
                TextField("", value: $amount, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                if q.type != .portion { Text(q.type.unitName) }
            }
            Text("**\(effectiveCalories.formatted())** kcal\(scaledMacroPreview)")
        }
    }

    // MARK: Search results (shown while searching)

    @ViewBuilder
    private var searchResults: some View {
        List {
            if !foodResults.isEmpty {
                Section("Foods") {
                    ForEach(foodResults) { food in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(food.name)
                                    if food.isGeneric {
                                        Text("Generic").font(.caption2)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(.secondary.opacity(0.15), in: Capsule())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if let first = food.quantities.first {
                                    Text(first.label).font(.caption).foregroundStyle(.secondary)   // e.g. "100 g"
                                }
                            }
                            Spacer()
                            if let first = food.quantities.first {
                                Text("\(first.calories.formatted()) kcal").foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectFood(food) }
                    }
                }
            }

            if !entryResults.isEmpty {
                Section("Quick entries") {
                    ForEach(entryResults) { entry in
                        CalorieEntryView(calories: entry.calories,
                                         narrative: entry.narrative ?? "Quick calories",
                                         manufacturer: entry.manufacturer,
                                         protein: entry.protein,
                                         carbs: entry.carbs,
                                         fat: entry.fat,
                                         isGeneric: entry.isGenericFood,
                                         detailed: true)
                            .contentShape(Rectangle())
                            .onTapGesture { prefill(from: entry) }
                    }
                }
            }

            if foodResults.isEmpty && entryResults.isEmpty {
                Text("No matches.").foregroundStyle(.secondary)
            }
            
            if !settingsObj.offSearchDisabled {
                Section {
                    Button {
                        showingOFFSheet = true
                    } label: {
                        Label("Search OpenFoodFacts", systemImage: "globe")
                    }
                } footer: {
                    Text("Not finding it in your foods? Search the OpenFoodFacts database.")
                }
            }
        }
    }
    
    @ViewBuilder
    private var previousEntriesSection: some View {
        Section(header: Text("Recent entries")) {
            Picker("Scope", selection: $showAllFoods) {
                Text("Current meal").tag(false)
                Text("All meals").tag(true)
            }.pickerStyle(.segmented)

            if displayedFoods.isEmpty {
                Text("Nothing logged recently.").foregroundStyle(.secondary)
            } else {
                ForEach(displayedFoods) { entry in
                    CalorieEntryView(calories: entry.calories,
                                     narrative: entry.narrative ?? "Quick calories",
                                     manufacturer: entry.manufacturer,
                                     protein: entry.protein,
                                     carbs: entry.carbs,
                                     fat: entry.fat,
                                     isGeneric: entry.isGenericFood,
                                     detailed: true)
                        .contentShape(Rectangle())
                        .onTapGesture { prefill(from: entry) }
                }
            }
        }
    }
    
    // MARK: Selection handlers

    private func selectFood(_ food: PickedFood) {
        selectedFood = food
        selectedQuantityIndex = 0
        amount = food.quantities.first?.count ?? 0
        reAddClone = nil
        searchText = ""   // dismiss search → return to the form in scaling mode
    }

    private func prefill(from entry: CalorieEntry) {
        whatItIs = entry.narrative ?? "Quick calories"
        calories = entry.calories
        manufacturer = entry.manufacturer ?? ""
        protein = entry.protein; carbs = entry.carbs; fat = entry.fat
        alsoSave = false
        selectedFood = nil
        reAddClone = entry.isFoodEntry ? entry : nil
        searchText = ""   // dismiss search → return to the form, prefilled
    }

    // MARK: Persistence

    func saveEntry() async {
        if let food = selectedFood, let q = pickedQuantity {
            // Logging an existing food, scaled by the amount.
            await dataStore.addFoodEntry(foodItemID: food.persistedID, name: food.name,
                                         manufacturer: food.manufacturer,
                                         quantity: q, servings: effectiveServings,
                                         date: selectedDate, meal: selectedMeal)
        } else if let clone = reAddClone, (calories ?? 0) == clone.calories {
            // Re-adding a past food entry, untouched — keep its serving/macros/link.
            await dataStore.calorieActor.reAddEntry(from: clone, date: selectedDate, meal: selectedMeal)
        } else if alsoSave {
            // New entry the user wants to keep: build a food from it and log linked.
            let mfr = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            let quantity = FoodQuantity(type: saveServingUnit, count: saveServingCount,
                                        calories: calories!, protein: protein, carbs: carbs, fat: fat)
            let food = FoodItem(name: whatItIs.trimmingCharacters(in: .whitespacesAndNewlines),
                                manufacturer: mfr.isEmpty ? nil : mfr,
                                quantities: [quantity], source: .userInput)
            await dataStore.foodItemActor.insert(food)
            await dataStore.addFoodEntry(foodItemID: food.id, name: food.name,
                                         manufacturer: food.manufacturer,
                                         quantity: quantity, servings: 1,
                                         date: selectedDate, meal: selectedMeal)
        } else {
            // Plain quick entry.
            let mfr = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            await dataStore.addCalories(calories: calories!, narrative: whatItIs,
                                        date: selectedDate, meal: selectedMeal,
                                        manufacturer: mfr.isEmpty ? nil : mfr,
                                        protein: protein, fat: fat, carbs: carbs)
        }
        await dataStore.updateLump(todayLump: todayLump)
    }

    func resetInputs() {
        calories = nil
        whatItIs = ""
        manufacturer = ""
        protein = nil; carbs = nil; fat = nil
        alsoSave = false
        saveServingUnit = .portion
        saveServingCount = 1
        selectedFood = nil
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
