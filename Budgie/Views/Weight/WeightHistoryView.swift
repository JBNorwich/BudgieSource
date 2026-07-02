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
import Charts

struct WeightHistoryView: View {
    @EnvironmentObject var todayLump: TodayLump

    @State private var points: [WeightPoint] = []
    @State private var ownEntries: [HKQuantitySample] = []
    @State private var otherEntries: [HKQuantitySample] = []
    @State private var showAddSheet = false
    @State private var showGoalSheet = false

    // Default range: the last month, up to (and including) today.
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? getWeekBeforeDate(date: Date())
    @State private var endDate: Date = getMidnightOnDayAfter(date: Date())
    @State private var dateChanged: Bool = false

    private var unit: weightUnits {
        weightUnits(rawValue: settingsObj.weightDisplayUnit) ?? .kilograms
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                ChartDatePicker(startDate: $startDate, endDate: $endDate, dateChanged: $dateChanged)
                chart
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
        .task { await load() }
        .onChange(of: dateChanged) {
            if dateChanged {
                Task { await load() }
                dateChanged = false
            }
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

    @ViewBuilder private var chart: some View {
        if points.isEmpty {
            ContentUnavailableView("No weight data", systemImage: "scalemass",
                description: Text("Log your weight, or record it in another Health app, to see your trend."))
                .frame(height: 220)
        } else {
            Chart(points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Weight", plotValue(point.kilos)))
                PointMark(x: .value("Date", point.date), y: .value("Weight", plotValue(point.kilos)))
            }
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(axisLabel(v))
                        }
                    }
                }
            }
            .frame(height: 220)
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

    /// The value plotted on the Y axis, in the user's chosen unit, so the ticks land on round numbers of that unit.
    private func plotValue(_ kilos: Double) -> Double {
        switch unit {
        case .kilograms:            return kilos
        case .pounds, .stonepounds: return kilos / lbInKg   // pounds; stone+pounds is plotted on a pound scale
        }
    }

    /// Format a Y-axis tick (already in the plotted unit) via the app's standard weight formatter.
    private func axisLabel(_ value: Double) -> String {
        let kilos = (unit == .kilograms) ? value : value * lbInKg
        return renderWeight(kilos: kilos)
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map { plotValue($0.kilos) }
        guard let lo = values.min(), let hi = values.max() else { return 0...100 }
        let pad = max((hi - lo) * 0.15, 1)
        return (lo - pad)...(hi + pad)
    }

    private func load() async {
        let from = getStartOfDay(date: startDate)
        let to = endDate
        points = await dataStore.weightSeries(from: from, to: to)
        ownEntries = await dataStore.fetchBudgieWeightSamples(from: from, to: to)
        otherEntries = await dataStore.fetchOtherWeightSamples(from: from, to: to)
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
