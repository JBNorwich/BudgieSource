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
import SwiftUI
import Combine

struct MacFoodPane: View {
    @EnvironmentObject private var todayLump: TodayLump
    @State private var selectedDate = Date()
    @State private var entries: [CalorieEntry] = []
    @State private var meals: [Meal] = []
    @State private var reloadToken = UUID()
    @State private var showAdd = false
    @State private var editing: CalorieEntry?
    @ObservedObject private var syncMonitor = CloudSyncMonitor.shared

    private enum Row: Identifiable {
        case header(Meal)
        case entry(CalorieEntry, isFirst: Bool)
        case footer(mealID: UUID, eaten: Int, target: Int?)
        var id: String {
            switch self {
            case .header(let m):        return "h-\(m.mealUUID)"
            case .entry(let e, _):      return "e-\(e.id)"
            case .footer(let id, _, _): return "f-\(id)"
            }
        }
    }
    
    private var grouped: [(meal: Meal, items: [CalorieEntry])] {
        let byMeal = Dictionary(grouping: entries, by: \.meal)
        return meals.sorted { $0.order < $1.order }.compactMap { meal in
            let items = (byMeal[meal.mealUUID] ?? []).sorted { $0.date < $1.date }
            return items.isEmpty ? nil : (meal, items)
        }
    }
    
    private var rows: [Row] {
        grouped.flatMap { group -> [Row] in
            let eaten = group.items.reduce(0) { $0 + $1.calories }
            let target = todayLump.mealAllocationTargets[group.meal.mealUUID]   // nil unless allocations on
            var r: [Row] = [.header(group.meal)]
            r += group.items.enumerated().map { i, e in Row.entry(e, isFirst: i == 0) }
            r.append(.footer(mealID: group.meal.mealUUID, eaten: eaten, target: target))
            return r
        }
    }
    
    private var taskKey: String { "\(selectedDate.timeIntervalSince1970)|\(reloadToken)" }

    var body: some View {
        Group {
            if entries.isEmpty {
                if syncMonitor.isImporting {
                    SyncingUnavailableView()
                } else {
                    ContentUnavailableView("Nothing logged in Budgie Diet", systemImage: "fork.knife",
                        description: Text(selectedDate.formatted(date: .abbreviated, time: .omitted)))
                }
            } else {
                List {
                    ForEach(rows) { row in
                        switch row {
                        case .header(let meal):
                            Text(meal.name.uppercased())
                                .font(.subheadline).foregroundStyle(.secondary)
                                .padding(.top, 10)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        case .entry(let entry, let isFirst):
                            HStack {
                                Text(entry.narrative ?? "Quick calories")
                                Spacer()
                                Text("\(entry.calories) kcal").monospacedDigit().foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = entry }
                            .listRowBackground(mealCard(isFirst: isFirst, isLast: false))
                            .listRowSeparator(.visible)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) { delete(entry) }
                            }
                            .contextMenu {
                                Button("Edit") { editing = entry }
                                Button("Delete", role: .destructive) { delete(entry) }
                            }
                        case .footer(_, let eaten, let target):
                            HStack {
                                Spacer()
                                if let target {
                                    Text("**\(eaten.formatted())** / \(target.formatted()) kcal")
                                        .fontWeight(.bold)
                                } else {
                                    Text("**\(eaten.formatted())** kcal")
                                        .fontWeight(.bold)
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                            .listRowBackground(mealCard(isFirst: false, isLast: true))
                            .listRowSeparator(.hidden)
                        }
                    }
                    if todayLump.healthKitCalories != 0 {
                        Text("Calories from other apps")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.top, 10)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        HStack {
                            Text("Calories from other apps")
                            Spacer()
                            Text("\(todayLump.healthKitCalories) kcal").monospacedDigit().foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .listRowBackground(mealCard(isFirst: true, isLast: true))
                        .listRowSeparator(.visible)
                        Label("These are calories logged in Health by other apps. You'll need to go to the app that logged them to change or delete them. These won't sync here in real time, they will only update when your iPhone syncs.", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(20, for: .scrollContent)
            }
        }
        .navigationTitle("Food")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Button("Add food", systemImage: "plus") { showAdd = true }
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                MacDateNavigator(date: $selectedDate)
                Spacer()
            }
        }
        .task(id: taskKey) { await reload() }
        .sheet(isPresented: $showAdd) {
            MacAddFoodSheet(initialDate: selectedDate) { await reload() }.environmentObject(todayLump)
        }
        .sheet(item: $editing) { entry in
            MacEditFoodSheet(entry: entry) { await reload() }.environmentObject(todayLump)
        }
        .padding()
        
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        let start = getStartOfDay(date: selectedDate)
        entries = await dataStore.calorieActor.fetchCalsBetween(from: start, to: getMidnightOnDayAfter(date: start))
        meals = await dataStore.calorieActor.getListOfMeals()
    }
    private func delete(_ entry: CalorieEntry) {
        Task {
            await dataStore.calorieActor.deleteEntries(objects: [entry])
            await dataStore.updateLump(todayLump: todayLump)
            await reload()
        }
    }
}

/// One continuous material card per group: round only the top of the first row and the bottom of the last.
@ViewBuilder
func mealCard(isFirst: Bool, isLast: Bool) -> some View {
    UnevenRoundedRectangle(
        topLeadingRadius: isFirst ? 10 : 0,
        bottomLeadingRadius: isLast ? 10 : 0,
        bottomTrailingRadius: isLast ? 10 : 0,
        topTrailingRadius: isFirst ? 10 : 0
    )
    .fill(.regularMaterial)
}
