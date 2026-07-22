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
import Combine

struct MacFoodPane: View {
    @EnvironmentObject private var todayLump: TodayLump
    @State private var selectedDate = Date()
    @State private var entries: [CalorieEntry] = []
    @State private var meals: [Meal] = []
    @State private var reloadToken = UUID()
    @State private var showAdd = false
    @State private var showMealEditor = false
    @State private var editing: CalorieEntry?
    @ObservedObject private var syncMonitor = CloudSyncMonitor.shared

    private enum Row: Identifiable {
        case header(Meal)
        case entry(CalorieEntry, isFirst: Bool)
        case footer(mealID: UUID, eaten: Int, target: Int?)
        var id: String {
            switch self {
            case .header(let m):        return "h-\(m.mealUUID)"
            case .entry(let e, _):      return "e-\(e.id)"
            case .footer(let id, _, _): return "f-\(id)"
            }
        }
    }
    
    private var grouped: [(meal: Meal, items: [CalorieEntry])] {
        let byMeal = Dictionary(grouping: entries, by: \.meal)
        return meals.sorted { $0.order < $1.order }.compactMap { meal in
            let items = (byMeal[meal.mealUUID] ?? []).sorted { $0.date < $1.date }
            return items.isEmpty ? nil : (meal, items)
        }
    }
    
    private var rows: [Row] {
        grouped.flatMap { group -> [Row] in
            let eaten = group.items.reduce(0) { $0 + $1.calories }
            let target = todayLump.mealAllocationTargets[group.meal.mealUUID]   // nil unless allocations on
            var r: [Row] = [.header(group.meal)]
            r += group.items.enumerated().map { i, e in Row.entry(e, isFirst: i == 0) }
            r.append(.footer(mealID: group.meal.mealUUID, eaten: eaten, target: target))
            return r
        }
    }
    
    private var taskKey: String { "\(selectedDate.timeIntervalSince1970)|\(reloadToken)" }

    var body: some View {
        Group {
            if entries.isEmpty {
                if syncMonitor.isImporting {
                    SyncingUnavailableView()
                } else {
                    ContentUnavailableView("Nothing logged in Budgie Diet", systemImage: "fork.knife",
                        description: Text(selectedDate.formatted(date: .abbreviated, time: .omitted)))
                }
            } else {
                List {
                    ForEach(rows) { row in
                        switch row {
                        case .header(let meal):
                            Text(meal.name.uppercased())
                                .font(.subheadline).foregroundStyle(.secondary)
                                .padding(.top, 10)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        case .entry(let entry, let isFirst):
                            CalorieEntryView(calories: entry.calories,
                                             narrative: entry.narrative ?? "Quick calories",
                                             manufacturer: entry.manufacturer,
                                             protein: entry.protein, carbs: entry.carbs, fat: entry.fat,
                                             isGeneric: entry.isGenericFood,
                                             detailed: true)
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = entry }
                            .listRowBackground(mealCard(isFirst: isFirst, isLast: false))
                            .listRowSeparator(.visible)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) { delete(entry) }
                            }
                            .contextMenu {
                                Button("Edit") { editing = entry }
                                Button("Delete", role: .destructive) { delete(entry) }
                            }
                        case .footer(_, let eaten, let target):
                            HStack {
                                Spacer()
                                if let target {
                                    Text("**\(eaten.formatted())** / \(target.formatted()) kcal")
                                        .fontWeight(.bold)
                                } else {
                                    Text("**\(eaten.formatted())** kcal")
                                        .fontWeight(.bold)
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                            .listRowBackground(mealCard(isFirst: false, isLast: true))
                            .listRowSeparator(.hidden)
                        }
                    }
                    if Calendar.current.isDateInToday(selectedDate) && todayLump.healthKitCalories != 0 {
                        Text("Calories from other apps")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.top, 10)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        HStack {
                            Spacer()
                            Text("\(todayLump.healthKitCalories) kcal").monospacedDigit().foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .listRowBackground(mealCard(isFirst: true, isLast: true))
                        .listRowSeparator(.visible)
                        Label("These are calories logged in Health by other apps. You'll need to go to the app that logged them to change or delete them. These won't sync here in real time, they will only update when your iPhone syncs.", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(20, for: .scrollContent)
            }
        }
        .navigationTitle("Food")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Button("New custom meal…", systemImage: "list.bullet.rectangle.portrait") { showMealEditor = true }
                Button("Add food", systemImage: "plus") { showAdd = true }
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                MacDateNavigator(date: $selectedDate)
                Spacer()
            }
        }
        .task(id: taskKey) { await reload() }
        .sheet(isPresented: $showAdd) {
            MacAddFoodSheet(initialDate: selectedDate) { await reload() }.environmentObject(todayLump)
        }
        .sheet(item: $editing) { entry in
            MacEditFoodSheet(entry: entry) { await reload() }.environmentObject(todayLump)
        }
        .sheet(isPresented: $showMealEditor) {
            MacMealEditorSheet { await reload() }
        }
        .padding()
        .onRemoteStoreChange { await reload() }
    }

    private func reload() async {
        let start = getStartOfDay(date: selectedDate)
        async let entriesTask = dataStore.calorieActor.fetchCalsBetween(from: start, to: getMidnightOnDayAfter(date: start))
        async let mealsTask = dataStore.calorieActor.getListOfMeals()
        (entries, meals) = await (entriesTask, mealsTask)
    }
    private func delete(_ entry: CalorieEntry) {
        Task {
            await dataStore.calorieActor.deleteEntries(objects: [entry])
            await dataStore.updateLump(todayLump: todayLump)
            await reload()
        }
    }
}

/// One continuous material card per group: round only the top of the first row and the bottom of the last.
@ViewBuilder
func mealCard(isFirst: Bool, isLast: Bool) -> some View {
    UnevenRoundedRectangle(
        topLeadingRadius: isFirst ? 10 : 0,
        bottomLeadingRadius: isLast ? 10 : 0,
        bottomTrailingRadius: isLast ? 10 : 0,
        topTrailingRadius: isFirst ? 10 : 0
    )
    .fill(.regularMaterial)
}

// MARK: - Custom meal editor (Mac). Lives here, next to the Food pane that surfaces it, because a
// new file can't easily be added to the Mac target — mirrors MealEditorView.swift (iOS-only).

/// Creates or edits a custom meal: a FoodItem whose single serving is baked from a list of other
/// saved foods (its `components`). Once saved it's just an ordinary FoodItem everywhere else in the
/// app — logging, search, recents and Shortcuts all need no knowledge of how it was composed.
struct MacMealEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: () async -> Void = {}

    private let existingID: UUID?
    @State private var name: String
    @State private var batchYield: Double
    @State private var components: [MealComponent]
    @State private var resolvedFoods: [UUID: FoodItem] = [:]
    @State private var addingComponent = false
    @State private var componentsLoaded = false
    @State private var isSaving = false

    /// Pass an existing custom meal to edit it, or nothing to create a new one.
    init(existing: FoodItem? = nil, onSave: @escaping () async -> Void = {}) {
        self.existingID = existing?.id
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _batchYield = State(initialValue: existing?.batchYield ?? 1)
        _components = State(initialValue: existing?.components ?? [])
    }

    /// See MealEditorView.hasUnresolvableServing — same rule, kept in sync by hand since this file
    /// can't share code with the iOS-only editor.
    private func hasUnresolvableServing(_ component: MealComponent) -> Bool {
        guard let food = resolvedFoods[component.foodItemID] else { return false }
        return component.totals(in: food) == nil
    }

    private var canSave: Bool {
        !isSaving && componentsLoaded && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !components.isEmpty
            && batchYield > 0
            && components.allSatisfy { resolvedFoods[$0.foodItemID] != nil && !hasUnresolvableServing($0) }
    }

    private var previewQuantity: FoodQuantity {
        FoodItem.mealQuantity(components: components, resolvedFoods: resolvedFoods,
                              batchYield: batchYield, servingName: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $name)
                } header: {
                    Text(existingID == nil ? "New custom meal" : "Edit custom meal")
                }

                Section {
                    HStack {
                        Text("Makes")
                        Spacer()
                        TextField("", value: $batchYield, format: .number)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 60)
                        Text(batchYield == 1 ? "serving" : "servings")
                    }
                } footer: {
                    Text("Enter the number of servings the ingredients and their quantities you add make. You can always log more or less than one serving at a time, just like any other food.")
                }

                Section {
                    if components.isEmpty {
                        Text("Add the foods that make up this meal.").foregroundStyle(.secondary)
                    } else {
                        ForEach(components) { component in componentRow(component) }
                    }
                    Button {
                        addingComponent = true
                    } label: {
                        Label("Add ingredient", systemImage: "plus")
                    }
                } header: {
                    Text("Ingredients")
                } footer: {
                    if componentsLoaded && components.contains(where: { resolvedFoods[$0.foodItemID] == nil || hasUnresolvableServing($0) }) {
                        Text("One or more ingredients are no longer available. Remove or replace them to save your changes.")
                    }
                }

                if !components.isEmpty {
                    Section("Total") {
                        Text("**\(previewQuantity.calories.formatted())** kcal per serving")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { Task { await save() } }
                    .disabled(!canSave)
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 470, height: 640)
        .sheet(isPresented: $addingComponent) {
            MacMealComponentPicker { component, food in
                components.append(component)
                resolvedFoods[food.id] = food
            }
        }
        .task {
            // Resolve every existing component's food in one round trip so names/totals show
            // immediately, and gate Save on this finishing so an in-flight edit can't silently
            // save with missing ingredients.
            let missingIDs = Array(Set(components.map(\.foodItemID)).subtracting(resolvedFoods.keys))
            if !missingIDs.isEmpty {
                for food in await dataStore.foodItemActor.fetch(ids: missingIDs) {
                    resolvedFoods[food.id] = food
                }
            }
            componentsLoaded = true
        }
    }

    @ViewBuilder
    private func componentRow(_ component: MealComponent) -> some View {
        let food = resolvedFoods[component.foodItemID]
        let totals = food.flatMap { component.totals(in: $0) }
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let food {
                    Text(food.name).lineLimit(1).truncationMode(.tail)
                    if totals != nil {
                        Text(componentLabel(component)).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Serving no longer available").font(.caption).foregroundStyle(.secondary)
                    }
                } else if !componentsLoaded {
                    Text("Loading…").foregroundStyle(.secondary)
                } else {
                    Text("Food no longer available").foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let t = totals {
                Text("\(t.calories.formatted()) kcal").foregroundStyle(.secondary)
            }
            Button {
                components.removeAll { $0.id == component.id }
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func componentLabel(_ component: MealComponent) -> String {
        component.servingUnit == .portion
            ? (component.servingAmount == 1 ? "1 portion" : "\(component.servingAmount.formatted()) portions")
            : "\(component.servingAmount.formatted()) \(component.servingUnit.unitName)"
    }

    private func save() async {
        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantity = FoodItem.mealQuantity(components: components, resolvedFoods: resolvedFoods,
                                             batchYield: batchYield, servingName: nil)
        if let existingID {
            await dataStore.foodItemActor.update(id: existingID, name: trimmedName, manufacturer: nil,
                                                 quantities: [quantity], components: components,
                                                 batchYield: batchYield)
            await dataStore.calorieActor.relabelEntries(forFood: existingID, name: trimmedName, manufacturer: nil)
        } else {
            let item = FoodItem(name: trimmedName, manufacturer: nil, quantities: [quantity], source: .customMeal)
            item.components = components
            item.batchYield = batchYield
            await dataStore.foodItemActor.insert(item)
        }
        await onSave()
        dismiss()
    }
}

/// Search-then-scale picker for adding one ingredient to a custom meal, on Mac. Mirrors
/// MacAddFoodSheet's search + serving-scaling flow, but hands back a MealComponent instead of
/// logging an entry — the Mac equivalent of MealEditorView's (iOS-only) MealComponentPickerView.
struct MacMealComponentPicker: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (MealComponent, FoodItem) -> Void

    @State private var searchText = ""
    @State private var results: [PickedFood] = []
    @State private var selected: PickedFood?
    @State private var selectedQuantityIndex = 0
    @State private var amount: Double = 0
    @State private var showingOFFSheet = false

    private var pickedQuantity: FoodQuantity? {
        guard let selected, selected.quantities.indices.contains(selectedQuantityIndex) else { return nil }
        return selected.quantities[selectedQuantityIndex]
    }
    private var effectiveServings: Double {
        guard let q = pickedQuantity, q.count > 0 else { return 0 }
        return amount / q.count
    }
    private var canAdd: Bool { pickedQuantity != nil && effectiveServings > 0 }

    private func select(_ food: PickedFood) {
        selected = food
        selectedQuantityIndex = 0
        amount = food.quantities.first?.count ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            if let selected {
                scalingForm(selected)
            } else {
                searchBody
            }
            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                if selected != nil {
                    Button("Add") { Task { await confirmAdd() } }
                        .disabled(!canAdd)
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 440, height: 520)
        .sheet(isPresented: $showingOFFSheet) {
            MacOFFSheet(term: searchText) { food in
                showingOFFSheet = false
                select(food)
            }
        }
        .task(id: searchText) {
            guard !searchText.isEmpty else { results = []; return }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            // No nesting: a custom meal can't itself be used as an ingredient of another meal.
            let mine = await dataStore.foodItemActor.search(term: searchText).filter { $0.source != .customMeal }
            let generic = FoodCatalogue.shared.search(searchText, excluding: mine)
            results = mine.map(\.asPicked) + generic.map(\.asPicked)
        }
    }

    private var searchBody: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search foods to add", text: $searchText).textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain)
                }
            }
            .padding()
            Divider()

            List {
                if results.isEmpty {
                    Text(searchText.isEmpty ? "Search for a food to add." : "No matches.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { food in ingredientRow(food) }
                }
                if !searchText.isEmpty && !settingsObj.offSearchDisabled {
                    Section {
                        Button { showingOFFSheet = true } label: {
                            Label("Search OpenFoodFacts", systemImage: "globe")
                        }
                    } footer: {
                        Text("Not finding it in your foods? Search the OpenFoodFacts database.")
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func ingredientRow(_ food: PickedFood) -> some View {
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
        .onTapGesture { select(food) }
    }

    @ViewBuilder
    private func scalingForm(_ food: PickedFood) -> some View {
        Form {
            Section {
                HStack {
                    Text(food.name).font(.headline)
                    Spacer()
                    Button("Change") { selected = nil }.buttonStyle(.borderless)
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
                    Text("**\(q.totals(servings: effectiveServings).calories.formatted())** kcal")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func confirmAdd() async {
        guard let selected, let q = pickedQuantity else { return }
        let food: FoodItem
        if let id = selected.persistedID, let existing = await dataStore.foodItemActor.fetch(id: id) {
            food = existing
        } else {
            // A bundled generic isn't a real FoodItem yet — save it so the meal has a stable id to
            // reference, same as any other saved food. Reuse an existing saved copy with an identical
            // name AND servings/calories if one already exists, rather than saving another.
            let signature = FoodSignature.make(name: selected.name, manufacturer: selected.manufacturer,
                                               quantities: selected.quantities)
            let candidates = await dataStore.foodItemActor.search(term: selected.name, includeArchived: true)
            if let match = candidates.first(where: {
                FoodSignature.make(name: $0.name, manufacturer: $0.manufacturer, quantities: $0.quantities) == signature
            }) {
                food = match
            } else {
                let created = FoodItem(name: selected.name, manufacturer: selected.manufacturer,
                                       quantities: selected.quantities, source: .userInput)
                await dataStore.foodItemActor.insert(created)
                if selected.manufacturer != nil { await dataStore.invalidateManufacturersCache() }
                food = created
            }
        }
        // Resolve to the matching serving on `food` itself (not `selected`), so the component's
        // servingID actually exists in `food.quantities` — see MealComponentPickerView.confirmAdd.
        let servingID = food.quantities.first(where: {
            $0.type == q.type && $0.count == q.count && $0.calories == q.calories
                && $0.protein == q.protein && $0.carbs == q.carbs && $0.fat == q.fat
        })?.id ?? q.id
        let component = MealComponent(foodItemID: food.id, servingID: servingID, servingUnit: q.type, servingAmount: amount)
        onAdd(component, food)
        dismiss()
    }
}
