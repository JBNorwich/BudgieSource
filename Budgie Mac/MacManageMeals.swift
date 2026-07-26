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

/// Mac equivalent of iOS `ManageMealsView`: rename, add, reorder, delete (with reassignment), and set each meal's
/// start time. The start time is what feeds `resolveMealForNow`, so this is where a Mac-only user turns on
/// time-of-day meal pre-selection. Kept in step with the iOS screen by hand, since the two targets don't share views.
struct MacManageMealsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var meals: [Meal] = []
    @State private var loaded = false

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
        VStack(spacing: 0) {
            Form {
                Section {
                    if !loaded {
                        Text("Loading…").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(meals.enumerated()), id: \.element.mealUUID) { index, meal in
                            mealRow(meal, index: index)
                        }
                    }
                } header: {
                    Text("Meals")
                } footer: {
                    Text("Give a meal a start time and it’ll be picked automatically when you log after then. Anything logged before your earliest start time goes to “Snacks/Other”, which can’t be removed so there’s always somewhere for your entries to live. Right-click a meal to rename or delete it, and use the arrows to reorder.")
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button {
                    newMealName = ""
                    showingAddAlert = true
                } label: {
                    Label("Add meal", systemImage: "plus")
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 470, height: 640)
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
            MacReassignMealSheet(
                mealToDelete: meal,
                candidates: meals.filter { $0.mealUUID != meal.mealUUID },
                onComplete: { await reload() }
            )
        }
    }

    @ViewBuilder
    private func mealRow(_ meal: Meal, index: Int) -> some View {
        HStack(spacing: 8) {
            Text(meal.name)
            if isProtected(meal) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            Spacer()
            startTimeControl(meal)
            reorderControls(index: index)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Rename…") {
                renameText = meal.name
                mealBeingRenamed = meal
            }
            if !isProtected(meal) {
                Button("Delete…", role: .destructive) { mealPendingDeletion = meal }
            }
        }
    }

    /// Up/down reordering. macOS `Form` doesn't support `.onMove` drag reordering, so meals are moved a step
    /// at a time with explicit buttons — reliable, accessible, and fine for something reordered rarely.
    @ViewBuilder
    private func reorderControls(index: Int) -> some View {
        HStack(spacing: 2) {
            Button { moveMeal(from: index, to: index - 1) } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(index == 0)
            .accessibilityLabel("Move up")

            Button { moveMeal(from: index, to: index + 1) } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(index == meals.count - 1)
            .accessibilityLabel("Move down")
        }
        .buttonStyle(.borderless)
    }

    /// Shows the start time (with a clear button) when one is set, or an "Add start time" affordance when it isn't.
    @ViewBuilder
    private func startTimeControl(_ meal: Meal) -> some View {
        if let minute = meal.startMinute {
            DatePicker("", selection: Binding(
                get: { minsIntoDayIntoTime(mins: minute) },
                set: { setStart(meal, timeToMinsIntoDay(time: $0)) }
            ), displayedComponents: .hourAndMinute)
                .labelsHidden()
            Button {
                setStart(meal, nil)
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove start time")
            .accessibilityLabel("Remove start time")
        } else {
            Button("Add start time") { setStart(meal, 0) }
                .font(.footnote)
                .buttonStyle(.borderless)
        }
    }

    private func setStart(_ meal: Meal, _ minute: Int?) {
        Task {
            await dataStore.calorieActor.setMealStartMinute(mealUUID: meal.mealUUID, minute: minute)
            await reload()
        }
    }

    private func reload() async {
        meals = await dataStore.calorieActor.getOrderedListOfMeals()
        loaded = true
    }

    private func moveMeal(from index: Int, to newIndex: Int) {
        guard meals.indices.contains(index), meals.indices.contains(newIndex) else { return }
        meals.swapAt(index, newIndex)
        let ordered = meals.map(\.mealUUID)
        Task {
            await dataStore.calorieActor.reorderMeals(orderedUUIDs: ordered)
            await reload()
        }
    }
}

/// Mac equivalent of iOS `ReassignMealSheet`: a deleted meal's entries have to land somewhere, so the user
/// picks a destination before the meal is removed.
private struct MacReassignMealSheet: View {
    let mealToDelete: Meal
    let candidates: [Meal]
    let onComplete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var targetUUID: UUID?

    private var footerText: String {
        var baseString = "All entries currently logged under “\(mealToDelete.name)” will be moved to the meal you choose. This can’t be undone."
        if settingsObj.useMealAllocations {
            baseString += "\n\nDeleting this won’t reapportion your allocations to different meals — you’ll need to re-set the remaining allocations."
        }
        return baseString
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Move entries to", selection: $targetUUID) {
                        ForEach(candidates) { meal in
                            Text(meal.name).tag(Optional(meal.mealUUID))
                        }
                    }
                } footer: {
                    Text(footerText)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
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
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 440, height: 280)
        .onAppear {
            // Default the target to Snacks/Other if available, otherwise the first candidate.
            targetUUID = candidates.first(where: { $0.mealUUID == settingsObj.snacksUUID })?.mealUUID
                ?? candidates.first?.mealUUID
        }
    }
}
