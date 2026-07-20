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

/// Pure-render water intake chart, with an optional goal line — day-varying when the user has
/// "increase goal with activity" on (each day topped up by that day's own active-calorie burn),
/// otherwise a flat line at the base goal. Takes already-fetched day-bucketed data and a matching
/// per-day goal series; does no fetching itself.
struct WaterChartView: View {
    var waterData: [WaterPoint]
    /// Per-day goal (ml), keyed by date, aligned with `waterData`. See `waterGoalSeries`.
    var goalByDay: [Date: Int]

    private var unit: volumeUnits {
        volumeUnits(rawValue: settingsObj.waterDisplayUnit) ?? .millilitres
    }

    private func plotValue(_ millilitres: Int) -> Double {
        Double(millilitres) / unit.millilitresPerUnit
    }

    /// Format a Y-axis tick (already in the plotted unit) via the app's standard volume formatter.
    private func axisLabel(_ value: Double) -> String {
        renderVolume(millilitres: Int((value * unit.millilitresPerUnit).rounded()))
    }

    var body: some View {
        if waterData.isEmpty {
            ContentUnavailableView("No water data", systemImage: "drop",
                description: Text("Log your water intake, or record it in another Health app, to see your trend."))
                .frame(height: 220)
        } else {
            Chart {
                ForEach(waterData) { point in
                    BarMark(x: .value("Date", point.date), y: .value("Water", plotValue(point.millilitres)))
                        .foregroundStyle(by: .value("Series", "Water"))
                    if let goal = goalByDay[point.date], goal > 0 {
                        LineMark(x: .value("Date", point.date), y: .value("Water", plotValue(goal)), series: .value("Line", "Goal"))
                            .foregroundStyle(by: .value("Series", "Goal"))
                            .lineStyle(StrokeStyle(dash: [5]))
                    }
                }
            }
            .chartForegroundStyleScale(["Water": Color.blue, "Goal": Color.teal])
            .chartLegend(.visible)
            .chartLegend(position: .bottom, alignment: .center)
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
            .chartPressPopup(dates: waterData.map(\.date)) { date in
                popupContent(for: date)
            }
        }
    }

    @ViewBuilder
    private func popupContent(for date: Date) -> some View {
        if let point = waterData.first(where: { $0.date == date }) {
            Text(renderVolume(millilitres: point.millilitres)).font(.caption)
            if let goal = goalByDay[date], goal > 0 {
                Text("Goal: " + renderVolume(millilitres: goal)).font(.caption2).foregroundStyle(.teal)
            }
        }
    }
}

#Preview {
    WaterChartView(waterData: [], goalByDay: [:])
}
