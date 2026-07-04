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
    @State private var selectedMeal = UUID()
    @State private var selectedDate = Date()
    @State private var mealList: [Meal] = []
    @State private var caloriesWereZero = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Calories", value: $calories, format: .number)
                    .textFieldStyle(.roundedBorder).font(.title2)
                TextField("Narrative (optional)", text: $narrative)
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
                Button("Save") { save() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 440, height: 360)
        .task { mealList = await dataStore.calorieActor.getListOfMeals() }
        .onAppear {
            calories = entry.calories
            narrative = entry.narrative ?? "Quick calories"
            selectedDate = entry.date
            selectedMeal = entry.meal
        }
        .onChange(of: narrative) { narrative = String(narrative.prefix(30)) }
        .alert("Calories must be above zero.", isPresented: $caloriesWereZero) { Button("OK", role: .cancel) {} }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        }
    }

    private func save() {
        guard calories > 0 else { caloriesWereZero = true; return }
        Task {
            await dataStore.calorieActor.updateCalories(entry: entry, calories: calories, narrative: narrative, date: selectedDate, meal: selectedMeal)
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
