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

struct ManageMealsView: View {
    @State private var meals: [Meal] = []

    // Add
    @State private var showingAddAlert = false
    @State private var newMealName = ""

    // Rename
    @State private var mealBeingRenamed: Meal?
    @State private var renameText = ""

    // Delete / reassign
    @State private var mealPendingDeletion: Meal?

    /// The Snacks/Other meal must always survive. Guard by UUID, falling back to name
    /// on the off-chance snacksUUID hasn't been populated yet.
    private func isProtected(_ meal: Meal) -> Bool {
        if let snacksUUID = settingsObj.snacksUUID { return meal.mealUUID == snacksUUID }
        return meal.name == "Snacks/Other"
    }

    var body: some View {
        List {
            Section(footer: Text("Give a meal a start time and it’ll be picked automatically when you log after then. Anything logged before your earliest start time goes to “Snacks/Other”, which can’t be removed so there’s always somewhere for your entries to live. Tap a meal’s name to rename it, swipe left to delete.")) {
                ForEach(meals) { meal in
                    HStack {
                        Text(meal.name)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                renameText = meal.name
                                mealBeingRenamed = meal
                            }
                        Spacer()
                        MealStartTimeControl(startMinute: meal.startMinute) { newMinute in
                            Task {
                                await dataStore.calorieActor.setMealStartMinute(mealUUID: meal.mealUUID, minute: newMinute)
                                await reload()
                            }
                        }
                        if isProtected(meal) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isProtected(meal) {
                            Button {
                                mealPendingDeletion = meal
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .onMove(perform: moveMeals)
            }
        }
        .navigationTitle("Manage meals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newMealName = ""
                    showingAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await reload() }

        // Add
        .alert("New meal", isPresented: $showingAddAlert) {
            TextField("Meal name", text: $newMealName)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                let name = newMealName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task {
                    await dataStore.calorieActor.addMeal(name: name)
                    await reload()
                }
            }
        } message: {
            Text("Your meal needs a name.")
        }

        // Rename
        .alert("Rename meal", isPresented: Binding(
            get: { mealBeingRenamed != nil },
            set: { if !$0 { mealBeingRenamed = nil } }
        )) {
            TextField("Meal name", text: $renameText)
            Button("Cancel", role: .cancel) { mealBeingRenamed = nil }
            Button("Save") {
                let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let uuid = mealBeingRenamed?.mealUUID, !name.isEmpty {
                    Task {
                        await dataStore.calorieActor.renameMeal(mealUUID: uuid, newName: name)
                        await reload()
                    }
                }
                mealBeingRenamed = nil
            }
        }

        // Delete + reassign
        .sheet(item: $mealPendingDeletion) { meal in
            ReassignMealSheet(
                mealToDelete: meal,
                candidates: meals.filter { $0.mealUUID != meal.mealUUID },
                onComplete: { await reload() }
            )
        }
    }

    private func reload() async {
        meals = await dataStore.calorieActor.getOrderedListOfMeals()
    }

    private func moveMeals(from source: IndexSet, to destination: Int) {
        meals.move(fromOffsets: source, toOffset: destination)
        let ordered = meals.map(\.mealUUID)
        Task {
            await dataStore.calorieActor.reorderMeals(orderedUUIDs: ordered)
            await reload()
        }
    }
}

private struct ReassignMealSheet: View {
    let mealToDelete: Meal
    let candidates: [Meal]
    let onComplete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var targetUUID: UUID?
    
    private func getFooterText() -> String {
        var baseString = "All entries currently logged under “\(mealToDelete.name)” will be moved to the meal you choose. This can’t be undone."
        if settingsObj.useMealAllocations {
            baseString += "\n\nDeleting this won't reapportion your allocations to different meals - you'll need to re-set the remaining allocations."
        }
        return baseString
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text(getFooterText())) {
                    Picker("Move entries to", selection: $targetUUID) {
                        ForEach(candidates) { meal in
                            Text(meal.name).tag(Optional(meal.mealUUID))
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        guard let target = targetUUID else { return }
                        let doomed = mealToDelete.mealUUID
                        let protectedUUID = settingsObj.snacksUUID
                        Task {
                            await dataStore.calorieActor.deleteMeal(mealUUID: doomed, reassignTo: target, protectedUUID: protectedUUID)
                            await onComplete()
                            dismiss()
                        }
                    } label: {
                        Text("Move entries & delete meal")
                    }
                    .disabled(targetUUID == nil)
                }
            }
            .navigationTitle("Delete meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Default the target to Snacks/Other if available, otherwise the first candidate.
                targetUUID = candidates.first(where: { $0.mealUUID == settingsObj.snacksUUID })?.mealUUID
                    ?? candidates.first?.mealUUID
            }
        }
    }
}

/// Inline start-time control for a meal row: shows a time when one is set (with a clear button),
/// or an "Add start time" affordance when it isn't. Changes are reported back via `onChange`
/// rather than mutating the meal directly, so persistence stays on the actor.
private struct MealStartTimeControl: View {
    let startMinute: Int?
    let onChange: (Int?) -> Void

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinute: startMinute ?? 0) },
            set: { onChange(Self.minute(from: $0)) }
        )
    }

    var body: some View {
        if startMinute != nil {
            HStack(spacing: 6) {
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Button {
                    onChange(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove start time")
            }
        } else {
            Button("Add start time") { onChange(0) }
                .font(.footnote)
                .buttonStyle(.borderless)
        }
    }

    private static func date(fromMinute minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }
    private static func minute(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
