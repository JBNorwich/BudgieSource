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

struct EditCalsSheet: View {
    @EnvironmentObject var todayLump: TodayLump
    @Environment(\.dismiss) private var dismiss
    var entryToEdit: CalorieEntry
    @FocusState var isFocused: Bool
    @State private var calories: Int = 0
    @State private var whatItIs: String = ""
    @State private var amount: Double = 0
    @State private var quantities: [FoodQuantity] = []
    @State private var selectedQuantityIndex: Int = 0
    @State private var selectedMeal: UUID = UUID()
    @State private var selectedDate: Date = Date()
    @State private var showValueAlert: Bool = false
    @State private var mealList: [Meal] = []
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?

    private var isFoodEntry: Bool { entryToEdit.isFoodEntry }
    private var canPickQuantity: Bool { isFoodEntry && !quantities.isEmpty }

    /// The serving the user has selected from the food (nil when the food's gone — we then rescale the stamp).
    private var pickedQuantity: FoodQuantity? {
        guard canPickQuantity, quantities.indices.contains(selectedQuantityIndex) else { return nil }
        return quantities[selectedQuantityIndex]
    }
    private var effectiveServings: Double {
        guard let q = pickedQuantity, q.count > 0 else { return 0 }
        return amount / q.count
    }
    /// The unit currently in force: the picked serving's, or the stamped one if the food is unavailable.
    private var displayUnit: FoodQuantityType? { pickedQuantity?.type ?? entryToEdit.servingUnit }

    /// Live totals for the preview and save — recomputed from the picked serving, or rescaled from the stamp.
    private var previewTotals: (calories: Int, protein: Double?, fat: Double?, carbs: Double?)? {
        if let q = pickedQuantity {
            let t = q.totals(servings: effectiveServings)
            return (t.calories, t.protein, t.fat, t.carbs)
        }
        return entryToEdit.rescaled(toAmount: amount)
    }

    private var canSave: Bool {
        isFoodEntry ? (amount > 0 && previewTotals != nil) : calories > 0
    }

    private func macroLine(_ t: (calories: Int, protein: Double?, fat: Double?, carbs: Double?)) -> String {
        let summary = macroSummary(protein: t.protein, carbs: t.carbs, fat: t.fat)
        return summary.isEmpty ? "" : "  ·  " + summary
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isFoodEntry {
                        VStack(alignment: .leading, spacing: 2) {
                            if let m = entryToEdit.manufacturer, !m.isEmpty {
                                Text(m).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(entryToEdit.narrative ?? "Food").font(.headline)
                        }

                        if canPickQuantity, quantities.count > 1 {
                            Picker("Serving", selection: Binding(
                                get: { selectedQuantityIndex },
                                set: { newIndex in
                                    selectedQuantityIndex = newIndex
                                    // Switching unit makes the old amount meaningless — default to the new serving.
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
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 90)
                                .focused($isFocused)
                            if let u = displayUnit, u != .portion { Text(u.unitName) }
                        }

                        if let t = previewTotals {
                            Text("**\(t.calories.formatted())** kcal\(macroLine(t))")
                        }
                    } else {
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

                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(mealList.sorted(by: {$0.order < $1.order})) { meal in
                            Text(meal.name).tag(meal.mealUUID)
                        }
                    }.pickerStyle(.menu)

                    DatePicker(selection: $selectedDate, in: ...Date(), displayedComponents: .date, label: { Text("Date") })

                    Button("Save changes") {
                        guard canSave else {
                            showValueAlert = true
                            isFocused = true
                            return
                        }
                        Task {
                            await saveEntry()
                            dismiss()
                        }
                    }.buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Edit food entry")
        .onAppear {
            calories = entryToEdit.calories
            whatItIs = entryToEdit.narrative ?? "Quick calories"
            amount = entryToEdit.servingAmount ?? 0
            selectedDate = entryToEdit.date
            selectedMeal = entryToEdit.meal
            protein = entryToEdit.protein
            carbs = entryToEdit.carbs
            fat = entryToEdit.fat
        }
        .task {
            mealList = await dataStore.calorieActor.getListOfMeals()
            if isFoodEntry, let id = entryToEdit.foodItem {
                let qs = await dataStore.foodItemActor.quantities(id: id)
                quantities = qs
                if qs.contains(where: { $0.type == entryToEdit.servingUnit }) {
                    // Default to the serving it was logged in — and, when several share that unit,
                    // the one whose rate matches what was actually logged.
                    selectedQuantityIndex = bestServingIndex(in: qs, forUnit: entryToEdit.servingUnit,
                                                             calories: entryToEdit.calories,
                                                             servingAmount: entryToEdit.servingAmount)
                } else if let first = qs.first {
                    selectedQuantityIndex = 0              // logged unit is gone; fall back to the first
                    amount = first.count
                }
            }
        }
        .alert(isFoodEntry ? "Amount must be above zero." : "Calories must be above zero.", isPresented: $showValueAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    func saveEntry() async {
        if isFoodEntry, let t = previewTotals {
            await dataStore.calorieActor.updateFoodEntry(entry: entryToEdit,
                                                         calories: t.calories,
                                                         servingUnit: displayUnit,
                                                         servingAmount: amount,
                                                         protein: t.protein,
                                                         fat: t.fat,
                                                         carbs: t.carbs,
                                                         date: selectedDate,
                                                         meal: selectedMeal)
        } else {
            await dataStore.calorieActor.updateCalories(entry: entryToEdit,
                                                        calories: calories,
                                                        narrative: whatItIs,
                                                        date: selectedDate,
                                                        meal: selectedMeal,
                                                        protein: protein, fat: fat, carbs: carbs)
        }
        await dataStore.updateLump(todayLump: todayLump)
    }
}
