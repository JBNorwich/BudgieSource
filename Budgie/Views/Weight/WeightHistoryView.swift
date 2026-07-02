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
import HealthKit

struct WeightHistoryView: View {
    @EnvironmentObject var todayLump: TodayLump

    @State private var ownEntries: [HKQuantitySample] = []
    @State private var otherEntries: [HKQuantitySample] = []
    @State private var showAddSheet = false

    var body: some View {
        List {
            Section(header: Text("Logged in Budgie Diet")) {
                if ownEntries.isEmpty {
                    Text("You haven't logged your weight in Budgie Diet in the last six months.")
                } else {
                    ForEach(ownEntries, id: \.uuid) { row(for: $0) }
                        .onDelete(perform: delete)
                }
            }

            if !otherEntries.isEmpty {
                Section(header: Text("Logged in other apps"),
                        footer: Text("These come from other apps via Apple Health. You'll need to change or delete them in the app that logged them.")) {
                    ForEach(otherEntries, id: \.uuid) { row(for: $0) }
                }
            }
        }
        .listStyle(.grouped)
        .navigationTitle("Weight log")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log weight", systemImage: "plus") { showAddSheet = true }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAddSheet, onDismiss: { Task { await load() } }) {
            LogWeightSheet(isDisplayed: $showAddSheet)
                .environmentObject(todayLump)
                .presentationDetents([.medium])
        }
    }

    private func row(for sample: HKQuantitySample) -> some View {
        HStack {
            Text(sample.startDate.formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(.secondary)
            Spacer()
            Text(renderWeight(kilos: sample.quantity.doubleValue(for: .gramUnit(with: .kilo))))
        }
    }

    private func load() async {
        let end = getMidnightOnDayAfter(date: Date())
        let start = Calendar.current.date(byAdding: .month, value: -6, to: end) ?? end
        ownEntries = await dataStore.fetchBudgieWeightSamples(from: start, to: end)
        otherEntries = await dataStore.fetchOtherWeightSamples(from: start, to: end)
    }

    private func delete(_ offsets: IndexSet) {
        let toDelete = offsets.map { ownEntries[$0] }
        ownEntries.remove(atOffsets: offsets)
        Task {
            for sample in toDelete {
                await dataStore.deleteHKSample(uuid: sample.uuid, type: weightSampleType)
            }
            await dataStore.updateLump(todayLump: todayLump)
            await load()
        }
    }
}
