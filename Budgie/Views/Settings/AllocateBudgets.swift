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

struct AllocateBudgetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var meals: [Meal] = []            // non-Snacks, ordered
    @State private var snacksName: String = "Snacks/Other"
    @State private var allocations: [UUID: Double] = [:]
    @State private var featureOn: Bool = settingsObj.useMealAllocations
    @State private var cancelled = false

    private var othersTotal: Double { allocations.values.reduce(0, +) }
    private var snacksPercent: Double { max(0, 100 - othersTotal) }
    private var isOverAllocated: Bool { othersTotal > 100 }
    
    /// The highest this meal's slider may reach: 100% minus whatever is already allotted to the *other* meals.
    private func maxAllowed(for meal: Meal) -> Double {
        let others = othersTotal - (allocations[meal.mealUUID] ?? 0)
        return max(0, 100 - others)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("When this is on, Budgie Diet shows a target for each meal based on the percentages below, and spreads your daily budget evenly across the day. “\(snacksName)” always gets whatever’s left over. This will also replace your \"left to eat now\" figure in the meter on the main page with your remaining budget.\n\nThis setting won't work properly if you log food outside of Budgie Diet, since Apple Health doesn't track your calories logged by individual meal. It's best not to turn this on if you plan to log food with other apps.")) {
                    Toggle("Allocate budget by meal", isOn: $featureOn)
                }

                if featureOn {
                    Section(header: Text("Percentage of daily budget")) {
                        ForEach(meals) { meal in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(meal.name)
                                    Spacer()
                                    Text("\(Int(allocations[meal.mealUUID] ?? 0))%")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                Slider(
                                    value: Binding(
                                        get: { allocations[meal.mealUUID] ?? 0 },
                                        set: { allocations[meal.mealUUID] = min($0.rounded(), maxAllowed(for: meal)) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }
                        }
                    }

                    Section {
                        HStack {
                            Text(snacksName)
                            Spacer()
                            Text("\(Int(snacksPercent))%")
                                .foregroundStyle(isOverAllocated ? .red : .secondary)
                                .monospacedDigit()
                        }
                    } header: {
                        Text("Remainder")
                    } footer: {
                        if isOverAllocated {
                            Text("Your meals add up to \(Int(othersTotal))%, which is more than 100%. Reduce them before saving.")
                                .foregroundStyle(.red)
                        } else {
                            Text("“\(snacksName)” automatically takes the remaining \(Int(snacksPercent))%.")
                        }
                    }
                }
            }
            .navigationTitle("Budget allocation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelled = true; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                        .disabled(isOverAllocated)
                }
            }
            .task { await load() }
            .onDisappear {
                // Every other settings screen commits instantly; don't let a back-swipe
                // silently discard changes. Explicit Cancel and invalid totals still discard.
                if !cancelled && !isOverAllocated { persist() }
            }
        }
    }

    private func load() async {
        let all = (await dataStore.calorieActor.getListOfMeals()).sorted { $0.order < $1.order }
        let snacksUUID = settingsObj.snacksUUID
        meals = all.filter { $0.mealUUID != snacksUUID }
        if let snacks = all.first(where: { $0.mealUUID == snacksUUID }) {
            snacksName = snacks.name
        }
        var alloc: [UUID: Double] = [:]
        for meal in meals { alloc[meal.mealUUID] = meal.budgetPercent }
        allocations = alloc
    }

    private func persist() {
        let toSave = allocations
        let on = featureOn
        Task {
            await dataStore.calorieActor.setMealAllocations(toSave)
            settingsObj.useMealAllocations = on
            settingsObj.sync()
        }
    }
}
