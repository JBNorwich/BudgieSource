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

/// The metrics this page can chart. Weight has its own dedicated screen (`WeightHistoryView`,
/// linked from `BudgetView`) rather than a tab here, matching how water/food already work: a
/// view-only chart with a link out to the "hub" where editing actually happens, not two separate
/// places to manage the same entries. Filtered by `ChartPage.availableMetrics` against the user's
/// macro feature toggle before ever being offered or loaded.
enum ChartMetric: String, CaseIterable, Identifiable, Hashable {
    case calories, macros, water

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calories: return "Calories"
        case .macros:   return "Macros"
        case .water:    return "Water"
        }
    }
}

enum ChartLoadPhase: Equatable {
    case loading
    case loaded(ChartMetric)
    case empty(ChartMetric)

    /// The metric this phase's content belongs to — nil while loading. Comparing this against
    /// `selectedMetric` is how the loader tells "switched tabs" (show the spinner) apart from
    /// "paged dates within the same tab" (keep the current chart up while refetching) — folded into
    /// the phase itself so the two can't be tracked as separately-mutated state that drifts out of sync.
    var metric: ChartMetric? {
        switch self {
        case .loading: return nil
        case .loaded(let m), .empty(let m): return m
        }
    }
}

/// Identifies one load request: whichever combination of metric, date range and refresh count
/// changes, SwiftUI cancels any in-flight `.task` and starts a fresh one — so a request that arrives
/// mid-fetch always wins rather than being silently dropped.
private struct ChartTaskKey: Equatable {
    var metric: ChartMetric
    var start: Date
    var end: Date
    var refreshNonce: Int
}

struct ChartPage: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var todayLump: TodayLump

    @State var selectedMetric: ChartMetric = .calories
    @State var startDate: Date
    @State var endDate: Date
    @State var dateChanged: Bool = false
    @State var refreshNonce: Int = 0
    @State var phase: ChartLoadPhase = .loading

    @State var calorieData: [ChartDataLump] = []
    @State var macroData: [MacroPoint] = []
    @State var macroGoalData: [MacroGoalPoint] = []
    /// `macroGoalData` keyed by date, built once alongside it — an O(1) lookup for
    /// `macroHistoryRow`, rather than rebuilding the dictionary on every row.
    @State var macroGoalsByDate: [Date: MacroGoalPoint] = [:]
    @State var waterData: [WaterPoint] = []
    @State var waterGoalByDay: [Date: Int] = [:]
    @State var openingWaterPage: Bool = false
    @State var selWaterDate: Date = Date()

    init() {
        let end = getMidnightOnDayAfter(date: Date())
        _endDate = State(initialValue: end)
        _startDate = State(initialValue: getWeekBeforeDate(date: end))
    }

    /// Metrics whose feature toggle is on — macros can be turned off entirely, and per
    /// ARCHITECTURE.md a disabled feature must not surface here in another guise.
    private var availableMetrics: [ChartMetric] {
        ChartMetric.allCases.filter { metric in
            switch metric {
            case .macros: return !settingsObj.disableMacros
            case .calories, .water: return true
            }
        }
    }

    /// Matches ChartTableRow's shape: protein/fat/carbs (actual/goal) in the middle, the combined
    /// kcal those macros represent as the right-hand headline figure.
    private func macroHistoryRow(_ point: MacroPoint) -> some View {
        let goal = macroGoalsByDate[point.date]
        let macroCals = point.protein * 4 + point.carbs * 4 + point.fat * 9
        return MetricRowLayout(date: point.date) {
            VStack(spacing: 2) {
                macroCardLine("PROTEIN", actual: point.protein, goal: goal?.protein)
                macroCardLine("FAT", actual: point.fat, goal: goal?.fat)
                macroCardLine("CARBS", actual: point.carbs, goal: goal?.carbs)
            }
        } right: {
            VStack {
                Text("FROM MACROS")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                Spacer()
                Text(macroCals.formatted())
                    .font(.title)
                    .minimumScaleFactor(0.1)
                    .scaledToFit()
                Text("kcal").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func macroCardLine(_ label: String, actual: Int, goal: Int?) -> some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            if let goal {
                Text("\(actual)/\(goal)g").font(.caption)
            } else {
                Text("\(actual)g").font(.caption)
            }
        }
    }

    /// Matches ChartTableRow's shape: that day's goal in the middle, absolute volume on the right.
    /// Tap navigates to `WaterPage` for the day, same as before.
    private func waterHistoryRow(_ point: WaterPoint) -> some View {
        let goal = waterGoalByDay[point.date]
        return MetricRowLayout(date: point.date) {
            VStack(spacing: 2) {
                HStack {
                    Text("GOAL").font(.caption)
                    Spacer()
                    Text(goal.map { renderVolume(millilitres: $0) } ?? "–").font(.caption)
                }
            }
        } right: {
            VStack {
                Spacer()
                Text(renderVolume(millilitres: point.millilitres))
                    .font(.title)
                    .minimumScaleFactor(0.1)
                    .scaledToFit()
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selWaterDate = point.date
            openingWaterPage = true
        }
    }

    private var pagingGesture: some Gesture {
        pagingSwipeGesture(startDate: $startDate, endDate: $endDate, stepComponent: .day, stepValue: 7)
    }

    var body: some View {
        VStack {
            if availableMetrics.count > 1 {
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(availableMetrics) { metric in
                        Text(metric.label).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
            }

            ChartDatePicker(startDate: $startDate, endDate: $endDate, dateChanged: $dateChanged)

            switch phase {
            case .loading:
                ProgressView(label: {
                    Text("Loading")
                        .font(.caption)
                        .foregroundColor(.secondary)
                })
                .progressViewStyle(.circular)
                .frame(maxHeight: .infinity)
            case .empty(_):
                Label("No data was returned. Either you have no data in Health, or you didn't give Budgie Diet permissions to see your data.", systemImage: "exclamationmark.octagon")
                Spacer()
            case .loaded(_):
                switch selectedMetric {
                case .calories:
                    CalorieChartView(chartData: calorieData)
                        .gesture(pagingGesture)
                    ChartTableView(chartData: calorieData.sorted { $0.date > $1.date }).environmentObject(todayLump)
                case .macros:
                    MacroChartView(macroData: macroData, goalData: macroGoalData)
                        .gesture(pagingGesture)
                    MetricHistoryList(rows: macroData.sorted { $0.date > $1.date }) { point in
                        macroHistoryRow(point)
                    }
                case .water:
                    WaterChartView(waterData: waterData, goalByDay: waterGoalByDay)
                        .gesture(pagingGesture)
                    MetricHistoryList(rows: waterData.sorted { $0.date > $1.date }) { point in
                        waterHistoryRow(point)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("History")
        .navigationDestination(isPresented: $openingWaterPage) {
            WaterPage(curDate: selWaterDate).environmentObject(todayLump)
        }
        .task(id: ChartTaskKey(metric: selectedMetric, start: startDate, end: endDate, refreshNonce: refreshNonce)) {
            // A feature toggled off while this metric was selected — fall back rather than load it.
            guard availableMetrics.contains(selectedMetric) else {
                selectedMetric = .calories
                return
            }
            // Only show the spinner on a genuine metric switch (or the very first load) — paging the
            // date range within the same metric (via the picker or a swipe) keeps the current chart
            // visible while the new data loads, then cross-fades into it below, rather than flashing
            // back to a blank spinner on every page.
            if phase.metric != selectedMetric {
                phase = .loading
            }
            switch selectedMetric {
            case .calories:
                let data = await dataStore.calorieSeries(from: startDate, to: endDate)
                withAnimation(.easeInOut(duration: 0.25)) {
                    calorieData = data
                    phase = data.isEmpty ? .empty(.calories) : .loaded(.calories)
                }
            case .macros:
                // Padded by a week so the first visible day's percentage-mode goal is based on a
                // full trailing average, not a partial one — see `macroGoalSeries`/`rollingAverageDays`.
                // Only burn data is needed for the goal calculation, not the full calorie series.
                let paddedStart = getWeekBeforeDate(date: startDate)
                async let macroTask = dataStore.macroSeries(from: startDate, to: endDate)
                async let burnTask = dataStore.burnSeries(from: paddedStart, to: endDate)
                let (data, burnForGoals) = await (macroTask, burnTask)
                let goals = macroGoalSeries(calorieData: burnForGoals, forDates: data.map(\.date))
                withAnimation(.easeInOut(duration: 0.25)) {
                    macroData = data
                    macroGoalData = goals
                    macroGoalsByDate = Dictionary(uniqueKeysWithValues: goals.map { ($0.date, $0) })
                    phase = data.isEmpty ? .empty(.macros) : .loaded(.macros)
                }
            case .water:
                // Only burn data is needed for the activity-adjusted goal, not the full calorie series.
                async let waterTask = dataStore.waterSeries(from: startDate, to: endDate)
                async let burnTask = dataStore.burnSeries(from: startDate, to: endDate)
                let (data, burnForGoal) = await (waterTask, burnTask)
                let goals = waterGoalSeries(calorieData: burnForGoal, forDates: data.map(\.date))
                withAnimation(.easeInOut(duration: 0.25)) {
                    waterData = data
                    waterGoalByDay = goals
                    phase = data.isEmpty ? .empty(.water) : .loaded(.water)
                }
            }
        }
        .onChange(of: dateChanged) {
            dateChanged = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshNonce += 1
            }
        }
    }
}

/// Reverse-chronological daily readout beneath a chart — the `ScrollView`/whale-easter-egg wrapper
/// shared by the macro and water tabs, whose rows (built on `MetricRowLayout`, same as
/// `ChartTableView`'s) are supplied by the caller.
private struct MetricHistoryList<Row: Identifiable, RowContent: View>: View {
    var rows: [Row]
    @ViewBuilder var rowContent: (Row) -> RowContent

    var body: some View {
        ScrollView {
            ForEach(rows) { row in
                rowContent(row)
                Divider()
            }
            if settingsObj.whalesEverywhere == true {
                VStack {
                    Spacer()
                    Text("🐋 " + (whaleSalutations.randomElement() ?? "Whoops, I'm a whale."))
                        .padding()
                }.frame(minHeight: 100)
            }
        }
    }
}

#Preview {
    struct Preview: View {
        @State var lump = TodayLump()

        var body: some View {
            ChartPage().environmentObject(lump)
        }
    }

    return Preview()
}
