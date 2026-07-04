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
    @State private var calories: Int?
    @State private var narrative = ""
    @State private var selectedMeal: UUID = settingsObj.snacksUUID ?? UUID()
    @State private var mealList: [Meal] = []
    @State private var caloriesWereZero = false

    @State private var searchText = ""
    @State private var showAllFoods = false
    @State private var recent: [CalorieEntry] = []
    @State private var reloadToken = UUID()

    init(initialDate: Date, onSave: @escaping () async -> Void = {}) {
        _selectedDate = State(initialValue: initialDate)
        self.onSave = onSave
    }

    private var isToday: Bool {
        getMidnightOnDayBefore(date: Date()) == getMidnightOnDayBefore(date: selectedDate)
    }
    private var newCalsIn: Int { (calories ?? 0) + todayLump.eatenCalories }
    private var newRemBudg: Int { todayLump.totalBudgetRem - (calories ?? 0) }
    private var selectedMealName: String { mealList.first { $0.mealUUID == selectedMeal }?.name ?? "this meal" }
    private var mealTarget: Int? { todayLump.mealAllocationTargets[selectedMeal] }
    private var newMealRem: Int { (mealTarget ?? 0) - (todayLump.mealTotalList[selectedMeal] ?? 0) - (calories ?? 0) }
    private var queryKey: String { "\(searchText)|\(showAllFoods)|\(selectedMeal)|\(reloadToken)" }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Calories", value: $calories, format: .number)
                        .textFieldStyle(.roundedBorder).font(.title2)
                    TextField("Narrative (optional)", text: $narrative)
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(mealList) { Text($0.name).tag($0.mealUUID) }
                    }
                    DatePicker("Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                }

                if isToday {
                    Section {
                        Text("This will take your total calories in today to **\(newCalsIn.formatted())** and leave you **\(abs(newRemBudg).formatted())** \(newRemBudg >= 0 ? "in" : "over") your overall budget for the rest of the day.")
                        if settingsObj.useMealAllocations, mealTarget != nil {
                            Text("It'll also leave you **\(abs(newMealRem).formatted())** \(newMealRem >= 0 ? "in" : "over") your allocation for \(selectedMealName).")
                        }
                    }
                }

                Section("Previous entries") {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search", text: $searchText).textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain)
                        }
                    }
                    Picker("Scope", selection: $showAllFoods) {
                        Text("Current meal").tag(false)
                        Text("All meals").tag(true)
                    }.pickerStyle(.segmented).labelsHidden()
                    ForEach(recent, id: \.id) { entry in
                        HStack {
                            Text(entry.narrative ?? "Quick calories")
                            Spacer()
                            Text(entry.calories.formatted()).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { narrative = entry.narrative ?? "Quick calories"; calories = entry.calories }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save and add more") { save(keepOpen: true) }
                Button("Save") { save(keepOpen: false) }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 460, height: 580)
        .task { await loadMeals() }
        .task(id: queryKey) { await loadRecent() }
        .onChange(of: narrative) { narrative = String(narrative.prefix(30)) }
        .alert("Calories must be above zero.", isPresented: $caloriesWereZero) { Button("OK", role: .cancel) {} }
    }

    private func loadMeals() async {
        mealList = (await dataStore.calorieActor.getListOfMeals()).sorted { $0.order < $1.order }
        if !mealList.contains(where: { $0.mealUUID == selectedMeal }) {
            selectedMeal = mealList.first?.mealUUID ?? selectedMeal
        }
    }
    private func loadRecent() async {
        if searchText.isEmpty {
            let scope = showAllFoods ? nil : mealList.first { $0.mealUUID == selectedMeal }
            recent = await dataStore.calorieActor.fetchCalsForMeal(scope)
        } else {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            recent = await dataStore.calorieActor.searchCals(term: searchText, meal: showAllFoods ? nil : selectedMeal)
        }
    }
    private func save(keepOpen: Bool) {
        guard (calories ?? 0) > 0 else { caloriesWereZero = true; return }
        Task {
            await dataStore.addCalories(calories: calories!, narrative: narrative, date: selectedDate, meal: selectedMeal)
            await dataStore.updateLump(todayLump: todayLump)
            await onSave()
            if keepOpen { calories = nil; narrative = ""; reloadToken = UUID() } else { dismiss() }
        }
    }
}
