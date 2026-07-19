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

    /// Pass an existing custom meal to edit it, or nothing to create a new one.
    init(existing: FoodItem? = nil, isModal: Bool = false) {
        self.existingID = existing?.id
        self.isModal = isModal
        _name = State(initialValue: existing?.name ?? "")
        _batchYield = State(initialValue: existing?.batchYield ?? 1)
        _components = State(initialValue: existing?.components ?? [])
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !components.isEmpty
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
                HStack {
                    Text("Makes")
                    Spacer()
                    TextField("", value: $batchYield, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 60)
                    Text(batchYield == 1 ? "serving" : "servings")
                }
            } footer: {
                Text("Enter the number of servings the ingredients and their quantities you add make. You can always log more or less than one serving at a time, just like any other food.")
            }

            Section("Ingredients") {
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
            }

            if !components.isEmpty {
                Section("Total") {
                    Text("**\(previewQuantity.calories.formatted())** kcal per serving")
                }
            }
        }
        .navigationTitle(existingID == nil ? "New custom meal" : "Edit custom meal")
        .toolbar {
            if isModal {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await save()
                        dismiss()
                    }
                }.disabled(!canSave)
            }
        }
        .sheet(isPresented: $addingComponent) {
            NavigationStack {
                MealComponentPickerView { component, food in
                    components.append(component)
                    resolvedFoods[food.id] = food
                }
            }
        }
        .task {
            // Resolve every existing component's food up front so names/totals show immediately.
            for component in components where resolvedFoods[component.foodItemID] == nil {
                if let food = await dataStore.foodItemActor.fetch(id: component.foodItemID) {
                    resolvedFoods[component.foodItemID] = food
                }
            }
        }
    }

    @ViewBuilder
    private func componentRow(_ component: MealComponent) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let food = resolvedFoods[component.foodItemID] {
                    Text(food.name)
                    Text(componentLabel(component)).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Food no longer available").foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let food = resolvedFoods[component.foodItemID], let t = component.totals(in: food) {
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
    let onAdd: (MealComponent, FoodItem) -> Void

    @State private var searchText = ""
    @State private var results: [PickedFood] = []
    @State private var selected: PickedFood?
    @State private var selectedQuantityIndex = 0
    @State private var amount: Double = 0

    private var pickedQuantity: FoodQuantity? {
        guard let selected, selected.quantities.indices.contains(selectedQuantityIndex) else { return nil }
        return selected.quantities[selectedQuantityIndex]
    }
    private var effectiveServings: Double {
        guard let q = pickedQuantity, q.count > 0 else { return 0 }
        return amount / q.count
    }
    private var canAdd: Bool { pickedQuantity != nil && effectiveServings > 0 }

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
            if selected != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await confirmAdd() } }.disabled(!canAdd)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search foods")
        .task(id: searchText) {
            guard !searchText.isEmpty else { results = []; return }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            // No nesting: a custom meal can't itself be used as an ingredient of another meal.
            let mine = await dataStore.foodItemActor.search(term: searchText).filter { $0.source != .customMeal }
            // Drop any generic that's already saved under an identical name AND servings/calories —
            // a shared name alone isn't enough to call it the same food, so this only hides a true twin.
            let mineSignatures = Set(mine.map {
                FoodSignature.make(name: $0.name, manufacturer: $0.manufacturer, quantities: $0.quantities)
            })
            let generic = FoodCatalogue.shared.search(searchText).filter {
                !mineSignatures.contains(FoodSignature.make(name: $0.name, manufacturer: $0.manufacturer, quantities: $0.quantities))
            }
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
                    .onTapGesture {
                        selected = food
                        selectedQuantityIndex = 0
                        amount = food.quantities.first?.count ?? 0
                    }
                }
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
                    Text("**\(q.totals(servings: effectiveServings).calories.formatted())** kcal")
                }
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
            let candidates = await dataStore.foodItemActor.search(term: selected.name)
            if let match = candidates.first(where: {
                FoodSignature.make(name: $0.name, manufacturer: $0.manufacturer, quantities: $0.quantities) == signature
            }) {
                food = match
            } else {
                let created = FoodItem(name: selected.name, manufacturer: selected.manufacturer,
                                       quantities: selected.quantities, source: .userInput)
                await dataStore.foodItemActor.insert(created)
                food = created
            }
        }
        let component = MealComponent(foodItemID: food.id, servingUnit: q.type, servingAmount: amount)
        onAdd(component, food)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        MealEditorView()
    }
}
