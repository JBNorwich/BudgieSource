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

struct TodayFoodList: View {
    @EnvironmentObject var dataLump: TodayLump

    var groupedByMeal: [UUID: [CalorieEntry]] {
        Dictionary(grouping: dataLump.foodList, by: \.meal)
    }

    private var allocationsOn: Bool { settingsObj.useMealAllocations }

    /// Which meals to list: every meal (sorted) when planning by allocation, so the user can see empty meals and their targets; otherwise just the meals that have food logged today.
    private var displayedMeals: [Meal] {
        allocationsOn
            ? dataLump.allMeals.sorted { $0.order < $1.order }
            : dataLump.cleansedMealList
    }

    struct FoodHeaderView: View {
        let name: String
        let calsText: String

        var body: some View {
            HStack {
                Text(name.uppercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(calsText.uppercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The per-meal footer: eaten calories, plus "/ target" when allocations are on.
    @ViewBuilder
    private func mealTotalRow(for meal: Meal) -> some View {
        HStack {
            Spacer()
            let eaten = dataLump.mealTotalList[meal.mealUUID] ?? 0
            if let target = dataLump.mealAllocationTargets[meal.mealUUID] {
                Text("**\(eaten.formatted())** / \(target.formatted())")
            } else {
                Text("**\(eaten.formatted())**")
            }
        }
    }

    /// One meal's block: header, its entries (if any), a divider when there are entries, and the total row.
    @ViewBuilder
    private func mealSection(for meal: Meal, entries: [CalorieEntry]) -> some View {
        FoodHeaderView(name: meal.name, calsText: "CALORIES")
        ForEach(entries) { entry in
            CalorieEntryView(calories: entry.calories, narrative: entry.narrative ?? "Quick calories")
        }
        if !entries.isEmpty {
            HStack {
                Spacer()
                VStack {
                    Divider()
                        .frame(maxWidth: 50)
                }
            }
        }
        mealTotalRow(for: meal)
        Spacer()
    }

    @ViewBuilder
    private var healthKitSection: some View {
        if dataLump.healthKitCalories != 0 {
            Spacer()
            FoodHeaderView(name: "FROM OTHER APPS", calsText: "CALORIES")
            // "Date" doesn't matter too much because it doesn't display where "realEntry" is false so we can pass whatever we want.
            CalorieEntryView(calories: dataLump.healthKitCalories, narrative: "Calories from Apple Health")
            Spacer()
        }
    }

    var body: some View {
        if allocationsOn {
            // Planning view: show every meal with its target, even those with no food yet.
            ForEach(displayedMeals) { meal in
                mealSection(for: meal, entries: groupedByMeal[meal.mealUUID] ?? [])
            }
            healthKitSection
        } else if !dataLump.foodList.isEmpty || dataLump.healthKitCalories != 0 {
            // Original behaviour: only meals that actually have food.
            if !dataLump.foodList.isEmpty {
                ForEach(displayedMeals) { meal in
                    let entries = groupedByMeal[meal.mealUUID] ?? []
                    if !entries.isEmpty {
                        mealSection(for: meal, entries: entries)
                    }
                }
            }
            healthKitSection
        } else {
            Text("You have no eaten calories logged today.")
        }
    }
}
