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
    @ObservedObject private var syncMonitor = CloudSyncMonitor.shared

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
        SectionHeaderRow(leftText: meal.name, rightText: "CALORIES")
        ForEach(entries) { entry in
            CalorieEntryView(calories: entry.calories, narrative: entry.narrative ?? "Quick calories")
        }
        if !entries.isEmpty {
            CenteredDivider(maxWidth: 50)
        }
        mealTotalRow(for: meal)
        Spacer()
    }

    @ViewBuilder
    private var healthKitSection: some View {
        if dataLump.healthKitCalories != 0 {
            Spacer()
            SectionHeaderRow(leftText: "FROM OTHER APPS", rightText: "CALORIES")
            // "Date" doesn't matter too much because it doesn't display where "realEntry" is false so we can pass whatever we want.
            CalorieEntryView(calories: dataLump.healthKitCalories, narrative: "Calories from Apple Health")
            Spacer()
        }
    }

    var body: some View {
        // Computed once per body evaluation rather than once per meal iteration below.
        let grouped = groupedByMeal
        if allocationsOn {
            // Planning view: show every meal with its target, even those with no food yet.
            ForEach(displayedMeals) { meal in
                mealSection(for: meal, entries: grouped[meal.mealUUID] ?? [])
            }
            healthKitSection
        } else if !dataLump.foodList.isEmpty || dataLump.healthKitCalories != 0 {
            // Original behaviour: only meals that actually have food.
            if !dataLump.foodList.isEmpty {
                ForEach(displayedMeals) { meal in
                    let entries = grouped[meal.mealUUID] ?? []
                    if !entries.isEmpty {
                        mealSection(for: meal, entries: entries)
                    }
                }
            }
            healthKitSection
        } else if syncMonitor.isImporting {
            Label("Syncing from iCloud…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        } else {
            Text("You have no eaten calories logged today.")
        }
    }
}
