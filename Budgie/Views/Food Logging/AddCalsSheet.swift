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
    @State private var saveServingName: String = ""
    @FocusState private var caloriesFocused: Bool

    // MARK: Food selection (scaling an existing food)
    @State private var selectedFood: PickedFood?
    @State private var selectedQuantityIndex: Int = 0
    @State private var amount: Double = 0

    // MARK: Search
    @State private var searchText: String = ""
    @State private var foodResults: [PickedFood] = []
    @State private var entryResults: [CalorieEntry] = []
    @State private var showAllFoods: Bool = false
    @State private var displayedItems: [RecentItem] = []
    @State private var showingOFFSheet = false
    @State private var editingFood: FoodItem?
    
    @State private var showingScanner = false
    @State private var scannedBarcode: ScannedBarcode?

    private struct ScannedBarcode: Identifiable {
        let id: String
        var barcode: String { id }
    }

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
    
    /// A recent entry resolved to what it should offer *now*: a live food's current recipe when it resolves to one, else the entry's own values (a quick calorie log).
    private struct RecentItem: Identifiable {
        let id: UUID
        let entry: CalorieEntry
        let food: PickedFood?
    }
    
    private var searchKey: SearchKey {
        SearchKey(term: searchText, allMeals: showAllFoods, meal: selectedMeal, reload: reloadToken)
    }
    
    init(selectedDate: Date, initialSearch: String = "", preselectedFood: PickedFood? = nil) {
        _selectedDate = State(initialValue: selectedDate)
        _searchText = State(initialValue: initialSearch)
        _selectedFood = State(initialValue: preselectedFood)
        if let food = preselectedFood {
            _amount = State(initialValue: food.quantities.first?.count ?? 0)
        }
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
        .sheet(item: $editingFood) { food in
            NavigationStack {
                FoodEditorView(existing: food, isModal: true)
            }
            .onDisappear { reloadToken = UUID() }   // pick up any edits
        }
        
        .toolbar {
            if !settingsObj.offSearchDisabled {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan barcode", systemImage: "barcode.viewfinder")
                    }
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerSheet { code in
                scannedBarcode = ScannedBarcode(id: code)
            }
        }
        .sheet(item: $scannedBarcode) { scanned in
            OpenFoodFactsSheet(barcode: scanned.barcode) { food in
                selectFood(food)
                scannedBarcode = nil
            }
        }
        
        .navigationTitle("Add food")
        .task(id: searchKey) {
            if searchText.isEmpty {
                let scope = showAllFoods ? nil : mealList.first { $0.mealUUID == selectedMeal }
                let recents = await dataStore.calorieActor.fetchCalsForMeal(scope)
                displayedItems = await resolveRecents(recents)
                foodResults = []
                entryResults = []
            } else {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                let mine = await dataStore.foodItemActor.search(term: searchText)
                let generic = FoodCatalogue.shared.search(searchText)
                foodResults = mine.map(\.asPicked) + generic.map(\.asPicked)
                let entries = await dataStore.calorieActor.searchCals(term: searchText, meal: nil)
                entryResults = entries.filter { $0.foodItem == nil && $0.servingUnit == nil }
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

            TextField("Serving name (optional), e.g. “1 medium banana”", text: $saveServingName)

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
                if food.quantities.count == 1, let q = food.quantities.first {
                    Text(q.label).font(.caption).foregroundStyle(.secondary)   // e.g. “1 medium banana”
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
                        pickedFoodRow(food) { selectFood(food) }
                            .swipeActions(edge: .leading) {           // swipe right → edit
                                if !food.isGeneric, let id = food.persistedID {
                                    Button {
                                        Task { editingFood = await dataStore.foodItemActor.fetch(id: id) }
                                    } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(.blue)
                                }
                            }
                            .swipeActions(edge: .trailing) {          // swipe left → archive
                                if !food.isGeneric, let id = food.persistedID {
                                    Button {
                                        Task {
                                            await dataStore.foodItemActor.setArchived(id: id, archived: true)
                                            reloadToken = UUID()       // re-runs the search; archived drops out
                                        }
                                    } label: { Label("Archive", systemImage: "archivebox") }
                                    .tint(.orange)
                                }
                            }
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
                            .onTapGesture { Task { await prefill(from: entry) } }
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

            if displayedItems.isEmpty {
                Text("Nothing logged recently.").foregroundStyle(.secondary)
            } else {
                ForEach(displayedItems) { item in
                    if let food = item.food {
                        pickedFoodRow(food) { selectFood(food) }         // current recipe → scale fresh
                    } else {
                        CalorieEntryView(calories: item.entry.calories,
                                         narrative: item.entry.narrative ?? "Quick calories",
                                         manufacturer: item.entry.manufacturer,
                                         protein: item.entry.protein,
                                         carbs: item.entry.carbs,
                                         fat: item.entry.fat,
                                         isGeneric: item.entry.isGenericFood,
                                         detailed: true)
                            .contentShape(Rectangle())
                            .onTapGesture { Task { await prefill(from: item.entry) } }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func pickedFoodRow(_ food: PickedFood, onTap: @escaping () -> Void) -> some View {
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
                let caption = [food.manufacturer, food.quantities.first?.label]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                if !caption.isEmpty {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let first = food.quantities.first {
                Text("\(first.calories.formatted()) kcal").foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
    
    // MARK: Selection handlers

    private func selectFood(_ food: PickedFood) {
        selectedFood = food
        selectedQuantityIndex = 0
        amount = food.quantities.first?.count ?? 0
        searchText = ""   // dismiss search → return to the form in scaling mode
    }

    private func prefill(from entry: CalorieEntry) async {
        if let picked = await resolveFood(for: entry) {
            // A logged food or generic → scaling mode, prefilled from the past entry.
            selectedFood = picked
            selectedQuantityIndex = bestServingIndex(in: picked, for: entry)
            amount = entry.servingAmount ?? (picked.quantities.first?.count ?? 1)
            alsoSave = false
            searchText = ""
        } else {
            // A genuine quick entry → manual prefill.
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
        guard let unit = entry.servingUnit else { return nil }   // no serving stamp → genuine quick entry
        let name = entry.narrative ?? ""
        if let match = FoodCatalogue.shared.search(name).first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return match.asPicked
        }
        let q = FoodQuantity(type: unit, count: entry.servingAmount ?? 1, calories: entry.calories,
                             protein: entry.protein, carbs: entry.carbs, fat: entry.fat)
        return PickedFood(id: UUID(), persistedID: nil, name: name.isEmpty ? "Food" : name,
                          manufacturer: entry.manufacturer, quantities: [q])
    }
    
    /// Best serving to re-open a past entry on: the one matching the entry's unit and, when several
    /// share that unit, the one whose per-unit calories are closest to what was actually logged —
    /// so a food with two same-unit servings re-opens on the one the entry really used.
    private func bestServingIndex(in food: PickedFood, for entry: CalorieEntry) -> Int {
        guard let unit = entry.servingUnit else { return 0 }
        let sameUnit = food.quantities.indices.filter { food.quantities[$0].type == unit }
        guard let first = sameUnit.first else { return 0 }
        guard let amount = entry.servingAmount, amount > 0 else { return first }
        let loggedRate = Double(entry.calories) / amount
        return sameUnit.min { rateGap(food.quantities[$0], loggedRate) < rateGap(food.quantities[$1], loggedRate) } ?? first
    }

    private func rateGap(_ q: FoodQuantity, _ rate: Double) -> Double {
        guard q.count > 0 else { return .greatestFiniteMagnitude }
        return abs(Double(q.calories) / q.count - rate)
    }

    /// For the recent list: entries linked to a live food show that food's current recipe (and re-add it fresh); archived or deleted foods are dropped so we don't suggest something you've retired; genuine quick entries keep their own values. One row per food, batched to one lookup per food.
    private func resolveRecents(_ entries: [CalorieEntry]) async -> [RecentItem] {
        var foodCache: [UUID: FoodItem?] = [:]
        var seenFoods = Set<UUID>()
        var items: [RecentItem] = []
        for entry in entries {
            if let id = entry.foodItem {
                if !foodCache.keys.contains(id) { foodCache[id] = await dataStore.foodItemActor.fetch(id: id) }
                guard let food = foodCache[id] ?? nil, !food.archived else { continue }   // gone or archived
                guard seenFoods.insert(food.id).inserted else { continue }                 // dedupe by food
                items.append(RecentItem(id: entry.id, entry: entry, food: food.asPicked))
            } else if entry.servingUnit != nil {
                let name = entry.narrative ?? ""
                let generic = FoodCatalogue.shared.search(name)
                    .first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.asPicked
                items.append(RecentItem(id: entry.id, entry: entry, food: generic))
            } else {
                items.append(RecentItem(id: entry.id, entry: entry, food: nil))            // quick entry
            }
        }
        return items
    }

    // MARK: Persistence

    func saveEntry() async {
        if let food = selectedFood, let q = pickedQuantity {
            // Logging an existing food, scaled by the amount.
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
            await dataStore.calorieActor.linkQuickEntries(toFood: newFoodID, name: newFoodName,
                                                          manufacturer: newFoodMfr, quantity: quantity)
            await dataStore.addFoodEntry(foodItemID: newFoodID, name: newFoodName,
                                         manufacturer: mfr.isEmpty ? nil : mfr,
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
        saveServingName = ""
        selectedFood = nil
        selectedQuantityIndex = 0
        amount = 0
    }
}

#Preview {
    NavigationStack {
        AddCalsSheet(selectedDate: Date()).environmentObject(TodayLump())
    }
}
