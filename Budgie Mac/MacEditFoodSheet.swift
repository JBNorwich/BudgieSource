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

struct MacEditFoodSheet: View {
    @EnvironmentObject private var todayLump: TodayLump
    @Environment(\.dismiss) private var dismiss

    let entry: CalorieEntry
    var onSave: () async -> Void = {}

    @State private var calories = 0
    @State private var narrative = ""
    @State private var amount: Double = 0
    @State private var quantities: [FoodQuantity] = []
    @State private var selectedQuantityIndex = 0
    @State private var selectedMeal = UUID()
    @State private var selectedDate = Date()
    @State private var mealList: [Meal] = []
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var valueWasZero = false
    @State private var confirmDelete = false

    private var isFoodEntry: Bool { entry.isFoodEntry }
    private var canPickQuantity: Bool { isFoodEntry && !quantities.isEmpty }

    private var pickedQuantity: FoodQuantity? {
        guard canPickQuantity, quantities.indices.contains(selectedQuantityIndex) else { return nil }
        return quantities[selectedQuantityIndex]
    }
    private var effectiveServings: Double {
        guard let q = pickedQuantity, q.count > 0 else { return 0 }
        return amount / q.count
    }
    private var displayUnit: FoodQuantityType? { pickedQuantity?.type ?? entry.servingUnit }

    private var previewTotals: (calories: Int, protein: Double?, fat: Double?, carbs: Double?)? {
        if let q = pickedQuantity {
            let t = q.totals(servings: effectiveServings)
            return (t.calories, t.protein, t.fat, t.carbs)
        }
        return entry.rescaled(toAmount: amount)
    }

    private var canSave: Bool {
        isFoodEntry ? (amount > 0 && previewTotals != nil) : calories > 0
    }

    private func macroLine(_ t: (calories: Int, protein: Double?, fat: Double?, carbs: Double?)) -> String {
        var parts: [String] = []
        if let p = t.protein { parts.append("P \(Int(p.rounded()))g") }
        if let c = t.carbs { parts.append("C \(Int(c.rounded()))g") }
        if let f = t.fat { parts.append("F \(Int(f.rounded()))g") }
        return parts.isEmpty ? "" : "  ·  " + parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if isFoodEntry {
                    VStack(alignment: .leading, spacing: 2) {
                        if let m = entry.manufacturer, !m.isEmpty {
                            Text(m).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(entry.narrative ?? "Food").font(.headline)
                    }

                    if canPickQuantity, quantities.count > 1 {
                        Picker("Serving", selection: Binding(
                            get: { selectedQuantityIndex },
                            set: { newIndex in
                                selectedQuantityIndex = newIndex
                                if quantities.indices.contains(newIndex) { amount = quantities[newIndex].count }
                            }
                        )) {
                            ForEach(quantities.indices, id: \.self) { i in
                                Text(quantities[i].label).tag(i)
                            }
                        }.pickerStyle(.menu)
                    }

                    HStack {
                        Text(displayUnit == .portion ? "Portions" : "Amount")
                        Spacer()
                        TextField("", value: $amount, format: .number)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 90)
                        if let u = displayUnit, u != .portion { Text(u.unitName) }
                    }

                    if let t = previewTotals {
                        Text("**\(t.calories.formatted())** kcal\(macroLine(t))")
                    }
                } else {
                    TextField("Calories", value: $calories, format: .number)
                        .textFieldStyle(.roundedBorder).font(.title2)
                    TextField("Narrative (optional)", text: $narrative)
                    DisclosureGroup("Nutrition (optional)") {
                        MacMacroFields(protein: $protein, carbs: $carbs, fat: $fat)
                    }
                }

                Picker("Meal", selection: $selectedMeal) {
                    ForEach(mealList.sorted { $0.order < $1.order }) { Text($0.name).tag($0.mealUUID) }
                }
                DatePicker("Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Delete", role: .destructive) { confirmDelete = true }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 440, height: 400)
        .task {
            mealList = await dataStore.calorieActor.getListOfMeals()
            if isFoodEntry, let id = entry.foodItem {
                let qs = await dataStore.foodItemActor.quantities(id: id)
                quantities = qs
                if let idx = qs.firstIndex(where: { $0.type == entry.servingUnit }) {
                    selectedQuantityIndex = idx
                } else if let first = qs.first {
                    selectedQuantityIndex = 0
                    amount = first.count
                }
            }
        }
        .onAppear {
            calories = entry.calories
            narrative = entry.narrative ?? "Quick calories"
            amount = entry.servingAmount ?? 0
            selectedDate = entry.date
            selectedMeal = entry.meal
            protein = entry.protein
            carbs = entry.carbs
            fat = entry.fat
        }
        .onChange(of: narrative) { narrative = String(narrative.prefix(30)) }
        .alert(isFoodEntry ? "Amount must be above zero." : "Calories must be above zero.", isPresented: $valueWasZero) {
            Button("OK", role: .cancel) {}
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        }
    }

    private func save() {
        guard canSave else { valueWasZero = true; return }
        Task {
            if isFoodEntry, let t = previewTotals {
                await dataStore.calorieActor.updateFoodEntry(entry: entry,
                                                             calories: t.calories,
                                                             servingUnit: displayUnit,
                                                             servingAmount: amount,
                                                             protein: t.protein, fat: t.fat, carbs: t.carbs,
                                                             date: selectedDate, meal: selectedMeal)
            } else {
                await dataStore.calorieActor.updateCalories(entry: entry,
                                                            calories: calories, narrative: narrative,
                                                            date: selectedDate, meal: selectedMeal,
                                                            protein: protein, fat: fat, carbs: carbs)
            }
            await dataStore.updateLump(todayLump: todayLump)
            await onSave(); dismiss()
        }
    }

    private func delete() {
        Task {
            await dataStore.calorieActor.deleteEntries(objects: [entry])
            await dataStore.updateLump(todayLump: todayLump)
            await onSave(); dismiss()
        }
    }
}
