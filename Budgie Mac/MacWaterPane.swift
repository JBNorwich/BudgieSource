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

struct MacWaterPane: View {
    @EnvironmentObject private var todayLump: TodayLump
    @State private var selectedDate = Date()
    @State private var entries: [WaterEntry] = []
    @State private var reloadToken = UUID()
    @State private var showAdd = false

    private var total: Int { entries.reduce(0) { $0 + $1.quantity } }
    private var sortedEntries: [WaterEntry] { entries.sorted { $0.date < $1.date } }
    private var taskKey: String { "\(selectedDate.timeIntervalSince1970)|\(reloadToken)" }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Total: \(renderVolume(millilitres: total))")
                    .font(.title2).fontWeight(.semibold)
                Spacer()
            }

            if entries.isEmpty {
                Spacer()
                ContentUnavailableView("No water logged", systemImage: "drop",
                    description: Text(selectedDate.formatted(date: .abbreviated, time: .omitted)))
                Spacer()
            } else {
                List {
                    Text("LOGGED IN BUDGIE DIET")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                        let isFirst = index == 0
                        let isLast = index == sortedEntries.count - 1
                        HStack {
                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(renderVolume(millilitres: entry.quantity))
                        }
                        .padding(.vertical, 7)
                        .listRowBackground(mealCard(isFirst: isFirst, isLast: isLast))
                        .listRowSeparator(isLast ? .hidden : .visible)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) { delete([entry]) }
                        }
                        .contextMenu { Button("Delete", role: .destructive) { delete([entry]) } }
                    }
                    if settingsObj.snapShotHKWater != 0 {
                        Text("LOGGED IN OTHER APPS")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        HStack {
                            Text("Logged in other apps")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(renderVolume(millilitres: settingsObj.snapShotHKWater))
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .listRowBackground(mealCard(isFirst: true, isLast: true))
                        Label("This is water logged in Health by other apps. You'll need to go to the app that logged these entries to change or delete them. These won't sync here in real time, they will only update when your iPhone syncs.", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(20, for: .scrollContent)
            }
        }
        .navigationTitle("Water")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Button("Add water", systemImage: "plus") { showAdd = true }
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                MacDateNavigator(date: $selectedDate)
                Spacer()
            }
        }
        .task(id: taskKey) { await reload() }
        .sheet(isPresented: $showAdd) {
            MacAddWaterSheet(dateToAddOn: getCurrentTimeonDate(date: selectedDate)) { await reload() }
                .environmentObject(todayLump)
        }
        .padding()
    }

    private func reload() async {
        entries = await dataStore.waterActor.getEntriesOnDate(date: selectedDate)
    }
    private func delete(_ items: [WaterEntry]) {
        Task {
            await dataStore.waterActor.deleteEntries(objects: items)
            await dataStore.updateLump(todayLump: todayLump)
            await reload()
        }
    }
}
