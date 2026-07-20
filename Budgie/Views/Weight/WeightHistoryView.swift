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

/// Identifies one load request for `WeightHistoryView` — `.task(id:)` re-fires whenever the visible
/// window changes, regardless of what changed it (the picker's arrows/full-picker sheet, or a swipe
/// on the chart), so a swipe reliably triggers a reload the same way `ChartPage`'s does.
private struct DateRangeKey: Equatable {
    var start: Date
    var end: Date
}

struct WeightHistoryView: View {
    @EnvironmentObject var todayLump: TodayLump

    @State private var trendPoints: [WeightTrendPoint] = []
    @State private var ownEntries: [HKQuantitySample] = []
    @State private var otherEntries: [HKQuantitySample] = []
    @State private var showAddSheet = false
    @State private var showGoalSheet = false

    // Default range: the last month, up to (and including) today.
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? getWeekBeforeDate(date: Date())
    @State private var endDate: Date = getMidnightOnDayAfter(date: Date())
    @State private var dateChanged: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                ChartDatePicker(startDate: $startDate, endDate: $endDate, dateChanged: $dateChanged, stepComponent: .month, stepValue: 1)
                WeightChartView(points: trendPoints, goalWeight: settingsObj.weightGoal)
                    .gesture(pagingSwipeGesture(startDate: $startDate, endDate: $endDate, stepComponent: .month, stepValue: 1))
            }
            .padding(.horizontal)
            .padding(.top)

            List {
                Section(header: Text("Logged in Budgie Diet")) {
                    if ownEntries.isEmpty {
                        Text("You haven't logged your weight in Budgie Diet in this period.")
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
        }
        .navigationTitle("Weight")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Change goal", systemImage: "target") { showGoalSheet = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log weight", systemImage: "plus") { showAddSheet = true }
            }
        }
        .task(id: DateRangeKey(start: startDate, end: endDate)) {
            await load()
        }
        .onChange(of: dateChanged) {
            dateChanged = false
        }
        .sheet(isPresented: $showAddSheet, onDismiss: { Task { await load() } }) {
            LogWeightSheet(isDisplayed: $showAddSheet)
                .environmentObject(todayLump)
                .presentationDetents([.medium])
        }
        
        .sheet(isPresented: $showGoalSheet) {
            NavigationStack {
                WeightGoalSheet(isDisplayed: $showGoalSheet)
                    .environmentObject(todayLump)
            }.presentationDetents([.medium])
        }.onDisappear() {
            Task {
                await dataStore.updateLump(todayLump: todayLump)
            }
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
        let from = getStartOfDay(date: startDate)
        let to = endDate
        async let trendTask = dataStore.fetchWeightTrend(from: from, to: to, surplusMode: settingsObj.surplusMode)
        async let ownTask = dataStore.fetchBudgieWeightSamples(from: from, to: to)
        async let otherTask = dataStore.fetchOtherWeightSamples(from: from, to: to)
        let (trend, own, other) = await (trendTask, ownTask, otherTask)
        withAnimation(.easeInOut(duration: 0.25)) {
            ownEntries = own
            otherEntries = other
            trendPoints = trend
        }
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
