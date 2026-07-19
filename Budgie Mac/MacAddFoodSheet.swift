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

struct MacAddFoodSheet: View {
    @EnvironmentObject private var todayLump: TodayLump
    @Environment(\.dismiss) private var dismiss

    var onSave: () async -> Void = {}

    @State private var selectedDate: Date
    @State private var selectedMeal: UUID = settingsObj.snacksUUID ?? UUID()
    @State private var mealList: [Meal] = []

    // Manual entry
    @State private var calories: Int?
    @State private var whatItIs = ""
    @State private var manufacturer = ""
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var alsoSave = false
    @State private var saveServingUnit: FoodQuantityType = .portion
    @State private var saveServingCount: Double = 1
    @State private var saveServingName: String = ""
    @State private var knownManufacturers: [String] = []

    // Food selection (scaling an existing food)
    @State private var selectedFood: PickedFood?
    @State private var selectedQuantityIndex = 0
    @State private var amount: Double = 0

    // Search
    @State private var searchText = ""
    @State private var showAllFoods = false
    @State private var recent: [CalorieEntry] = []
    @State private var foodResults: [PickedFood] = []
    @State private var entryResults: [CalorieEntry] = []
    @State private var showingOFFSheet = false
    @State private var reloadToken = UUID()

    init(initialDate: Date, onSave: @escaping () async -> Void = {}) {
        _selectedDate = State(initialValue: initialDate)
        self.onSave = onSave
    }

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

    private var isToday: Bool { Calendar.current.isDate(selectedDate, inSameDayAs: Date()) }
    private var newCalsIn: Int { effectiveCalories + todayLump.eatenCalories }
    private var newRemBudg: Int { todayLump.totalBudgetRem - effectiveCalories }
    private var selectedMealName: String { mealList.first { $0.mealUUID == selectedMeal }?.name ?? "this meal" }
    private var mealTarget: Int? { todayLump.mealAllocationTargets[selectedMeal] }
    private var newMealRem: Int { (mealTarget ?? 0) - (todayLump.mealTotalList[selectedMeal] ?? 0) - effectiveCalories }
    private var scaledMacroPreview: String {
        guard let q = pickedQuantity else { return "" }
        let t = q.totals(servings: effectiveServings)
        var parts: [String] = []
        if let p = t.protein { parts.append("P \(Int(p.rounded()))g") }
        if let c = t.carbs { parts.append("C \(Int(c.rounded()))g") }
        if let f = t.fat { parts.append("F \(Int(f.rounded()))g") }
        return parts.isEmpty ? "" : "  ·  " + parts.joined(separator: " · ")
    }

    private var queryKey: String { "\(searchText)|\(showAllFoods)|\(selectedMeal)|\(reloadToken)" }

    private var manufacturerSuggestions: [String] {
        suggestedManufacturers(for: manufacturer, in: knownManufacturers)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if let food = selectedFood {
                    Section { scalingContent(food) }
                } else {
                    Section { manualContent }
                }

                Section {
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(mealList) { Text($0.name).tag($0.mealUUID) }
                    }
                    DatePicker("Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)

                    if isToday {
                        Text("This will take your total calories in today to **\(newCalsIn.formatted())** and leave you **\(abs(newRemBudg).formatted())** \(newRemBudg >= 0 ? "in" : "over") your overall budget for the rest of the day.")
                        if settingsObj.useMealAllocations, mealTarget != nil {
                            Text("It'll also leave you **\(abs(newMealRem).formatted())** \(newMealRem >= 0 ? "in" : "over") your allocation for \(selectedMealName).")
                        }
                    }
                }

                if selectedFood == nil {
                    searchSection
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save and add more") { save(keepOpen: true) }
                    .disabled(!canSave)
                    .keyboardShortcut(.return, modifiers: [.command, .option])
                Button("Save") { save(keepOpen: false) }
                    .disabled(!canSave)
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 470, height: 640)
        .task { await loadMeals() }
        .task { knownManufacturers = await dataStore.knownManufacturers() }
        .task(id: queryKey) { await loadSearch() }
        .sheet(isPresented: $showingOFFSheet) {
            MacOFFSheet(term: searchText) { picked in
                selectFood(picked)
                showingOFFSheet = false
            }
        }
    }

    // MARK: Manual entry

    @ViewBuilder
    private var manualContent: some View {
        TextField("Calories", value: $calories, format: .number)
            .textFieldStyle(.roundedBorder).font(.title2)
        TextField("Name (optional)", text: $whatItIs)
        TextField("Manufacturer (optional)", text: $manufacturer)
            .textInputSuggestions {
                ForEach(manufacturerSuggestions, id: \.self) { name in
                    Text(name).textInputCompletion(name)
                }
            }

        DisclosureGroup("Nutrition (optional)") {
            MacMacroFields(protein: $protein, carbs: $carbs, fat: $fat)
        }

        Toggle("Also save to my foods", isOn: $alsoSave)

        if alsoSave {
            Picker("Measured in", selection: $saveServingUnit) {
                Text("Portion").tag(FoodQuantityType.portion)
                Text("Grams").tag(FoodQuantityType.grams)
                Text("Millilitres").tag(FoodQuantityType.millilitres)
            }.pickerStyle(.menu)

            TextField("Serving name (optional), e.g. “1 medium banana”", text: $saveServingName)

            HStack {
                Text(saveServingUnit == .portion ? "Servings" : "Amount")
                Spacer()
                TextField("", value: $saveServingCount, format: .number)
                    .multilineTextAlignment(.trailing).frame(maxWidth: 90)
                if saveServingUnit != .portion { Text(saveServingUnit.unitName) }
            }
        }
    }

    // MARK: Scaling an existing food

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
            Picker("Serving", selection: Binding(
                get: { selectedQuantityIndex },
                set: { newIndex in
                    selectedQuantityIndex = newIndex
                    if food.quantities.indices.contains(newIndex) { amount = food.quantities[newIndex].count }
                }
            )) {
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
                    .multilineTextAlignment(.trailing).frame(maxWidth: 90)
                if q.type != .portion { Text(q.type.unitName) }
            }
            Text("**\(effectiveCalories.formatted())** kcal\(scaledMacroPreview)")
        }
    }

    // MARK: Search

    @ViewBuilder
    private var searchSection: some View {
        Section {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search foods and past entries", text: $searchText).textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain)
                }
            }
        }

        if searchText.isEmpty {
            Section("Recent entries") {
                Picker("Scope", selection: $showAllFoods) {
                    Text("Current meal").tag(false)
                    Text("All meals").tag(true)
                }.pickerStyle(.segmented).labelsHidden()

                if recent.isEmpty {
                    Text("Nothing logged recently.").foregroundStyle(.secondary)
                } else {
                    ForEach(recent, id: \.id) { entry in entryRow(entry) }
                }
            }
        } else {
            if !foodResults.isEmpty {
                Section("Foods") {
                    ForEach(foodResults) { food in foodRow(food) }
                }
            }
            if !entryResults.isEmpty {
                Section("Quick entries") {
                    ForEach(entryResults, id: \.id) { entry in entryRow(entry) }
                }
            }
            if foodResults.isEmpty && entryResults.isEmpty {
                Section { Text("No matches.").foregroundStyle(.secondary) }
            }
            if !settingsObj.offSearchDisabled {
                Section {
                    Button { showingOFFSheet = true } label: {
                        Label("Search OpenFoodFacts", systemImage: "globe")
                    }
                } footer: {
                    Text("Not finding it in your foods? Search the OpenFoodFacts database.")
                }
            }
        }
    }

    @ViewBuilder
    private func foodRow(_ food: PickedFood) -> some View {
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
                    Text(first.label).font(.caption).foregroundStyle(.secondary)
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

    @ViewBuilder
    private func entryRow(_ entry: CalorieEntry) -> some View {
        CalorieEntryView(calories: entry.calories,
                         narrative: entry.narrative ?? "Quick calories",
                         manufacturer: entry.manufacturer,
                         protein: entry.protein, carbs: entry.carbs, fat: entry.fat,
                         isGeneric: entry.isGenericFood,
                         detailed: true)
            .contentShape(Rectangle())
            .onTapGesture { Task { await prefill(from: entry) } }
    }

    // MARK: Loading

    private func loadMeals() async {
        mealList = (await dataStore.calorieActor.getListOfMeals()).sorted { $0.order < $1.order }
        if !mealList.contains(where: { $0.mealUUID == selectedMeal }) {
            selectedMeal = mealList.first?.mealUUID ?? selectedMeal
        }
    }

    private func loadSearch() async {
        if searchText.isEmpty {
            let scope = showAllFoods ? nil : mealList.first { $0.mealUUID == selectedMeal }
            recent = await dataStore.calorieActor.fetchCalsForMeal(scope)
            foodResults = []
            entryResults = []
        } else {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let mine = await dataStore.foodItemActor.search(term: searchText)
            let generic = FoodCatalogue.shared.search(searchText, excluding: mine)
            foodResults = mine.map(\.asPicked) + generic.map(\.asPicked)
            let entries = await dataStore.calorieActor.searchCals(term: searchText, meal: nil)
            entryResults = entries.filter { $0.foodItem == nil && $0.servingUnit == nil }
        }
    }

    // MARK: Selection handlers

    private func selectFood(_ food: PickedFood) {
        selectedFood = food
        selectedQuantityIndex = 0
        amount = food.quantities.first?.count ?? 0
        searchText = ""
    }

    private func prefill(from entry: CalorieEntry) async {
        if let picked = await resolveFood(for: entry) {
            selectedFood = picked
            selectedQuantityIndex = bestServingIndex(in: picked.quantities, forUnit: entry.servingUnit,
                                                     calories: entry.calories, servingAmount: entry.servingAmount)
            amount = entry.servingAmount ?? (picked.quantities.first?.count ?? 1)
            alsoSave = false
            searchText = ""
        } else {
            whatItIs = entry.narrative ?? "Quick calories"
            calories = entry.calories
            manufacturer = entry.manufacturer ?? ""
            protein = entry.protein; carbs = entry.carbs; fat = entry.fat
            alsoSave = false
            selectedFood = nil
            searchText = ""
        }
    }

    /// Resolves the food behind a logged entry so re-adding behaves like a fresh log: the saved FoodItem,
    /// the bundled generic (by name), or a one-serving reconstruction from the entry's own stamp.
    private func resolveFood(for entry: CalorieEntry) async -> PickedFood? {
        if let id = entry.foodItem, let food = await dataStore.foodItemActor.fetch(id: id) {
            return food.asPicked
        }
        guard let unit = entry.servingUnit else { return nil }
        let name = entry.narrative ?? ""
        if let match = FoodCatalogue.shared.search(name).first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return match.asPicked
        }
        let q = FoodQuantity(type: unit, count: entry.servingAmount ?? 1, calories: entry.calories,
                             protein: entry.protein, carbs: entry.carbs, fat: entry.fat)
        return PickedFood(id: UUID(), persistedID: nil, name: name.isEmpty ? "Food" : name,
                          manufacturer: entry.manufacturer, quantities: [q])
    }

    // MARK: Persistence

    private func save(keepOpen: Bool) {
        guard canSave else { return }
        Task {
            await saveEntry()
            await onSave()
            if keepOpen { resetInputs(); reloadToken = UUID() } else { dismiss() }
        }
    }

    private func saveEntry() async {
        if let food = selectedFood, let q = pickedQuantity {
            await dataStore.addFoodEntry(foodItemID: food.persistedID, name: food.name,
                                         manufacturer: food.manufacturer,
                                         quantity: q, servings: effectiveServings,
                                         date: selectedDate, meal: selectedMeal)
        } else if alsoSave {
            let mfr = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            let servName = saveServingName.trimmingCharacters(in: .whitespacesAndNewlines)
            let quantity = FoodQuantity(type: saveServingUnit, count: saveServingCount,
                                        calories: calories!, protein: protein, carbs: carbs, fat: fat,
                                        servingName: servName.isEmpty ? nil : servName)
            let food = FoodItem(name: whatItIs.trimmingCharacters(in: .whitespacesAndNewlines),
                                manufacturer: mfr.isEmpty ? nil : mfr,
                                quantities: [quantity], source: .userInput)
            let newFoodID = food.id
            let newFoodName = food.name
            let newFoodMfr = food.manufacturer
            await dataStore.foodItemActor.insert(food)
            if newFoodMfr != nil { dataStore.invalidateManufacturersCache() }
            await dataStore.calorieActor.linkQuickEntries(toFood: newFoodID, name: newFoodName,
                                                          manufacturer: newFoodMfr, quantity: quantity)
            await dataStore.addFoodEntry(foodItemID: newFoodID, name: newFoodName,
                                         manufacturer: mfr.isEmpty ? nil : mfr,
                                         quantity: quantity, servings: 1,
                                         date: selectedDate, meal: selectedMeal)
        } else {
            let mfr = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            await dataStore.addCalories(calories: calories!, narrative: whatItIs,
                                        date: selectedDate, meal: selectedMeal,
                                        manufacturer: mfr.isEmpty ? nil : mfr,
                                        protein: protein, fat: fat, carbs: carbs)
        }
        await dataStore.updateLump(todayLump: todayLump)
    }

    private func resetInputs() {
        calories = nil
        whatItIs = ""
        manufacturer = ""
        protein = nil; carbs = nil; fat = nil
        alsoSave = false
        saveServingUnit = .portion
        saveServingCount = 1
        saveServingName = ""
        selectedFood = nil
        selectedQuantityIndex = 0
        amount = 0
    }
}

// MARK: - Inline macro fields (Mac equivalent of MacroEntryFields, which is iOS-only)

struct MacMacroFields: View {
    @Binding var protein: Double?
    @Binding var carbs: Double?
    @Binding var fat: Double?

    var body: some View {
        macroField("Protein", $protein)
        macroField("Carbs", $carbs)
        macroField("Fat", $fat)
    }

    @ViewBuilder
    private func macroField(_ label: String, _ value: Binding<Double?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: value.optionalNumberText)
                .multilineTextAlignment(.trailing).frame(maxWidth: 90)
            Text("g")
        }
    }
}

// MARK: - OpenFoodFacts search (Mac). Lives here because a new file can't be added to the Mac target.

struct MacOFFSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchTerm: String
    @State private var showingConsent: Bool
    var onImport: (PickedFood) -> Void

    @State private var results: [OFFProduct] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    init(term: String, onImport: @escaping (PickedFood) -> Void) {
        _searchTerm = State(initialValue: term)
        _showingConsent = State(initialValue: !settingsObj.offSearchConsented)
        self.onImport = onImport
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingConsent { consentView } else { searchBody }
            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
            }
            .padding()
        }
        .frame(width: 470, height: 560)
    }

    private var consentView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "globe").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("Search OpenFoodFacts?").font(.title2).bold()
            Text("Searching sends what you type to OpenFoodFacts, an external food database, over the internet. Like any web request, it reaches their servers directly, and what they do with it is covered by their privacy policy. Budgie Diet never sees or keeps your searches, and this feature stays off unless you turn it on. You'll only be asked this the first time you choose to search with OpenFoodFacts.\n\nOpenFoodFacts' data was contributed by many different people around the world, and it may not be accurate, correct or up to date.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Link("OpenFoodFacts privacy policy", destination: URL(string: "https://world.openfoodfacts.org/privacy")!)
                .font(.callout)
            Spacer()
            VStack(spacing: 10) {
                Button {
                    settingsObj.offSearchConsented = true
                    showingConsent = false
                } label: { Text("Search OpenFoodFacts").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                Button("Not now") { dismiss() }
                Button(role: .destructive) {
                    settingsObj.offSearchDisabled = true
                    dismiss()
                } label: { Text("Disable this feature") }
            }
        }
        .padding(24)
    }

    private var searchBody: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search OpenFoodFacts", text: $searchTerm)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await runSearch() } }
                Button("Search") { Task { await runSearch() } }
            }
            .padding()
            Divider()

            Group {
                if isSearching {
                    ProgressView("Searching…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView("Couldn't search", systemImage: "wifi.slash", description: Text(errorMessage))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchTerm)
                } else {
                    List(results) { product in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                if let brand = product.brand {
                                    Text(brand).font(.caption).foregroundStyle(.secondary)
                                }
                                if let first = product.quantities.first {
                                    Text(first.label).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if let first = product.quantities.first {
                                Text("\(first.calories.formatted()) kcal").foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { importProduct(product) }
                    }
                }
            }
        }
        .task { await runSearch() }
    }

    private func runSearch() async {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { results = []; return }
        isSearching = true
        errorMessage = nil
        do {
            results = try await OpenFoodFacts.search(term: term)
        } catch OpenFoodFacts.SearchError.rateLimited {
            errorMessage = "Too many searches just now — wait a moment and try again."
        } catch OpenFoodFacts.SearchError.serverUnavailable {
            errorMessage = "Food search is temporarily unavailable. Please try again in a moment."
        } catch {
            print("OFF search error: \(error)")
            errorMessage = "Couldn't reach OpenFoodFacts. Check your connection and try again."
        }
        isSearching = false
    }

    private func importProduct(_ product: OFFProduct) {
        let food = product.toFoodItem()
        Task {
            let picked = await dataStore.foodItemActor.importOFF(food)
            await MainActor.run {
                onImport(picked)
                dismiss()
            }
        }
    }
}
