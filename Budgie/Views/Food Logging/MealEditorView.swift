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

/// Creates or edits a custom meal: a FoodItem whose single serving is baked from a list of other
/// saved foods (its `components`). Once saved it's just an ordinary FoodItem everywhere else in the
/// app — logging, search, recents and Shortcuts all need no knowledge of how it was composed.
struct MealEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let existingID: UUID?
    private let isModal: Bool
    @State private var name: String
    @State private var batchYield: Double
    @State private var components: [MealComponent]
    @State private var resolvedFoods: [UUID: FoodItem] = [:]
    @State private var addingComponent = false
    @State private var componentsLoaded = false
    @State private var isSaving = false

    /// Pass an existing custom meal to edit it, or nothing to create a new one.
    init(existing: FoodItem? = nil, isModal: Bool = false) {
        self.existingID = existing?.id
        self.isModal = isModal
        _name = State(initialValue: existing?.name ?? "")
        _batchYield = State(initialValue: existing?.batchYield ?? 1)
        _components = State(initialValue: existing?.components ?? [])
    }

    /// True for a component whose food is still there but no longer has a serving it can resolve
    /// against (the specific serving, and any same-type fallback, were both removed since it was
    /// added) — distinct from the food itself being gone, which `resolvedFoods` already surfaces as
    /// "Food no longer available". Left unresolved, this component would silently drop out of the
    /// meal's total instead of blocking save, so it's surfaced and treated as blocking here too.
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
        Form {
            Section("Meal") {
                TextField("Name", text: $name)
            }

            Section {
                LabeledDoubleRow(label: "Makes", value: $batchYield,
                                suffix: batchYield == 1 ? "serving" : "servings", width: 60)
            } footer: {
                Text("Enter the number of servings the ingredients and their quantities you add make. You can always log more or less than one serving at a time, just like any other food.")
            }

            Section {
                if components.isEmpty {
                    Text("Add the foods that make up this meal.").foregroundStyle(.secondary)
                } else {
                    ForEach(components) { component in
                        componentRow(component)
                    }
                    .onDelete { components.remove(atOffsets: $0) }
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
        .navigationTitle(existingID == nil ? "New custom meal" : "Edit custom meal")
        .editorToolbar(isModal: isModal, canSave: canSave, isSaving: $isSaving) { await save() }
        .sheet(isPresented: $addingComponent) {
            NavigationStack {
                MealComponentPickerView { component, food in
                    components.append(component)
                    resolvedFoods[food.id] = food
                }
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
        }
    }

    private func componentLabel(_ component: MealComponent) -> String {
        component.servingUnit == .portion
            ? (component.servingAmount == 1 ? "1 portion" : "\(component.servingAmount.formatted()) portions")
            : "\(component.servingAmount.formatted()) \(component.servingUnit.unitName)"
    }

    private func save() async {
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
    }
}

/// Search-then-scale picker for adding one ingredient to a custom meal. Mirrors AddCalsSheet's
/// search + serving-scaling flow, but hands back a MealComponent instead of logging an entry.
private struct MealComponentPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissSearch) private var dismissSearch
    let onAdd: (MealComponent, FoodItem) -> Void

    @State private var searchText = ""
    @State private var results: [PickedFood] = []
    @State private var selected: PickedFood?
    @State private var selectedQuantityIndex = 0
    @State private var amount: Double = 0
    @State private var showingOFFSheet = false

    private var pickedQuantity: FoodQuantity? { selected?.quantities[safe: selectedQuantityIndex] }
    private var effectiveServings: Double { servingsScaled(pickedQuantity, amount: amount) }
    private var canAdd: Bool { pickedQuantity != nil && effectiveServings > 0 }

    private func select(_ food: PickedFood) {
        selected = food
        selectedQuantityIndex = 0
        amount = food.quantities.first?.count ?? 0
        dismissSearch()
    }

    var body: some View {
        Group {
            if let selected {
                scalingForm(selected)
            } else {
                searchList
            }
        }
        .navigationTitle("Add ingredient")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .barcodeScanning { food in select(food) }
        .searchable(text: $searchText, prompt: "Search foods")
        .sheet(isPresented: $showingOFFSheet) {
            OpenFoodFactsSheet(term: searchText) { food in
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

    @ViewBuilder
    private var searchList: some View {
        List {
            if results.isEmpty {
                Text(searchText.isEmpty ? "Search for a food to add." : "No matches.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { food in
                    PickedFoodRow(food: food) { select(food) }
                }
            }

            if !searchText.isEmpty {
                openFoodFactsSearchSection(showing: $showingOFFSheet)
            }
        }
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
                    ServingPicker(quantities: food.quantities, selectedIndex: $selectedQuantityIndex, amount: $amount)
                }

                if let q = pickedQuantity {
                    LabeledDoubleRow(label: q.type == .portion ? "Portions" : "Amount", value: $amount,
                                    suffix: q.type != .portion ? q.type.unitName : nil)
                    Text("**\(q.totals(servings: effectiveServings).calories.formatted())** kcal")
                }
            }

            Section {
                Button("Add") { Task { await confirmAdd() } }
                    .disabled(!canAdd)
            }
        }
    }

    private func confirmAdd() async {
        guard let selected, let q = pickedQuantity else { return }
        let food: FoodItem
        if let id = selected.persistedID, let existing = await dataStore.foodItemActor.fetch(id: id) {
            food = existing
        } else {
            // A bundled generic isn't a real FoodItem yet — save it so the meal has a stable id to
            // reference, same as any other saved food. Reuse an existing saved copy with an identical
            // name AND servings/calories if one already exists (e.g. from an earlier meal), rather
            // than saving another — a shared name alone isn't enough to call two foods the same.
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
        // `q`'s id was minted for `selected` (the catalogue pick or freshly-fetched food), which may
        // not be the same FoodQuantity instance as the one on `food` if an existing saved copy was
        // reused above — resolve to the matching serving on `food` itself so the component's
        // servingID actually exists in `food.quantities` instead of silently falling back to a
        // type-only match later. Compares macros too (not just type/count/calories), since a food
        // can have two servings that share all three but differ in protein/carbs/fat.
        let servingID = food.quantities.first(where: {
            $0.type == q.type && $0.count == q.count && $0.calories == q.calories
                && $0.protein == q.protein && $0.carbs == q.carbs && $0.fat == q.fat
        })?.id ?? q.id
        let component = MealComponent(foodItemID: food.id, servingID: servingID, servingUnit: q.type, servingAmount: amount)
        onAdd(component, food)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        MealEditorView()
    }
}
