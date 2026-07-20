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
import Charts

/// Pure-render macro (protein/fat/carbs) chart, with an optional day-varying goal line per macro
/// (dashed, matching colour). Takes already-fetched day-bucketed data and a matching per-day goal
/// series; does no fetching itself.
struct MacroChartView: View {
    var macroData: [MacroPoint]
    /// Per-day goals aligned by date with `macroData`. Varies day to day for a percentage-of-budget
    /// goal (see `macroGoalSeries`); constant for a fixed-gram goal. A day with no entry, or nil
    /// fields, means "no goal that day" — no line is drawn for it.
    var goalData: [MacroGoalPoint]

    var body: some View {
        if macroData.isEmpty {
            ContentUnavailableView("No macro data", systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Log food with protein, fat or carbs to see your trend."))
                .frame(height: 260)
        } else {
            Chart {
                ForEach(macroData) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Grams", point.protein), series: .value("Line", "Protein"))
                        .foregroundStyle(by: .value("Series", "Protein"))
                    LineMark(x: .value("Date", point.date), y: .value("Grams", point.fat), series: .value("Line", "Fat"))
                        .foregroundStyle(by: .value("Series", "Fat"))
                    LineMark(x: .value("Date", point.date), y: .value("Grams", point.carbs), series: .value("Line", "Carbs"))
                        .foregroundStyle(by: .value("Series", "Carbs"))
                }
                // Separate `series` identity from the actual-intake lines above (despite sharing the
                // same `foregroundStyle(by:)` colour category) so goal points connect to each other,
                // not to the actual-intake points — otherwise Swift Charts would draw one zigzagging
                // line alternating between actual grams and goal grams instead of two parallel ones.
                ForEach(goalData) { point in
                    if let protein = point.protein {
                        LineMark(x: .value("Date", point.date), y: .value("Grams", protein), series: .value("Line", "Protein goal"))
                            .foregroundStyle(by: .value("Series", "Protein"))
                            .lineStyle(StrokeStyle(dash: [5]))
                    }
                    if let fat = point.fat {
                        LineMark(x: .value("Date", point.date), y: .value("Grams", fat), series: .value("Line", "Fat goal"))
                            .foregroundStyle(by: .value("Series", "Fat"))
                            .lineStyle(StrokeStyle(dash: [5]))
                    }
                    if let carbs = point.carbs {
                        LineMark(x: .value("Date", point.date), y: .value("Grams", carbs), series: .value("Line", "Carbs goal"))
                            .foregroundStyle(by: .value("Series", "Carbs"))
                            .lineStyle(StrokeStyle(dash: [5]))
                    }
                }
            }
            .chartForegroundStyleScale(["Protein": Color.red, "Fat": Color.orange, "Carbs": Color.teal])
            .chartLegend(.visible)
            .chartLegend(position: .bottom, alignment: .center)
            .frame(height: 260)
            .chartPressPopup(dates: macroData.map(\.date)) { date in
                popupContent(for: date)
            }
        }
    }

    @ViewBuilder
    private func popupContent(for date: Date) -> some View {
        if let point = macroData.first(where: { $0.date == date }) {
            let goal = goalData.first(where: { $0.date == date })
            macroFigure("Protein", actual: point.protein, goal: goal?.protein, color: .red)
            macroFigure("Fat", actual: point.fat, goal: goal?.fat, color: .orange)
            macroFigure("Carbs", actual: point.carbs, goal: goal?.carbs, color: .teal)
        }
    }

    private func macroFigure(_ label: String, actual: Int, goal: Int?, color: Color) -> some View {
        Group {
            if let goal {
                Text("\(label): \(actual)/\(goal)g")
            } else {
                Text("\(label): \(actual)g")
            }
        }
        .font(.caption2)
        .foregroundStyle(color)
    }
}

#Preview {
    MacroChartView(macroData: [], goalData: [])
}
