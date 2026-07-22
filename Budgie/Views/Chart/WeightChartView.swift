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

/// Pure-render weight chart: raw logged entries, a smoothed weekly trend line, the day-by-day
/// "expected range" band derived from the recorded deficit (the historical generalisation of
/// `WeightView`'s single-point "Expected …–…" figure), and an optional goal reference line. Takes
/// already-computed `WeightTrendPoint`s (expected to include ~14 days of lead-in history before the
/// first day meant to be visible, so the band has full trailing windows from the start); does no
/// fetching itself.
struct WeightChartView: View {
    var points: [WeightTrendPoint]
    var goalWeight: Double

    private var unit: weightUnits {
        weightUnits(rawValue: settingsObj.weightDisplayUnit) ?? .kilograms
    }

    /// The value plotted on the Y axis, in the user's chosen unit, so the ticks land on round numbers of that unit.
    private func plotValue(_ kilos: Double) -> Double {
        switch unit {
        case .kilograms:            return kilos
        case .pounds, .stonepounds: return kilos / lbInKg
        }
    }

    /// Format a Y-axis tick (already in the plotted unit) via the app's standard weight formatter.
    private func axisLabel(_ value: Double) -> String {
        let kilos = (unit == .kilograms) ? value : value * lbInKg
        return renderWeight(kilos: kilos)
    }

    private var yDomain: ClosedRange<Double> {
        var values = points.flatMap {
            [$0.actualWeight, $0.trendWeight, $0.expectedLower, $0.expectedUpper].compactMap { $0.map(plotValue) }
        }
        if goalWeight != 0 { values.append(plotValue(goalWeight)) }
        guard let lo = values.min(), let hi = values.max() else { return 0...100 }
        let pad = max((hi - lo) * 0.15, 1)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        if points.allSatisfy({ $0.actualWeight == nil }) {
            ContentUnavailableView("No weight data", systemImage: "scalemass",
                description: Text("Log your weight, or record it in another Health app, to see your trend."))
                .frame(height: 300)
        } else {
            Chart {
                ForEach(points) { point in
                    if let lower = point.expectedLower, let upper = point.expectedUpper {
                        AreaMark(x: .value("Date", point.date),
                                yStart: .value("Weight", plotValue(lower)),
                                yEnd: .value("Weight", plotValue(upper)))
                            .foregroundStyle(by: .value("Series", "Expected range"))
                    }
                    if let trend = point.trendWeight {
                        LineMark(x: .value("Date", point.date), y: .value("Weight", plotValue(trend)))
                            .foregroundStyle(by: .value("Series", "Trend"))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    if let actual = point.actualWeight {
                        LineMark(x: .value("Date", point.date), y: .value("Weight", plotValue(actual)))
                            .foregroundStyle(by: .value("Series", "Weight"))
                        PointMark(x: .value("Date", point.date), y: .value("Weight", plotValue(actual)))
                            .foregroundStyle(by: .value("Series", "Weight"))
                    }
                }
                if goalWeight != 0 {
                    RuleMark(y: .value("Weight", plotValue(goalWeight)))
                        .foregroundStyle(by: .value("Series", "Goal"))
                        .lineStyle(.init(dash: [5]))
                }
            }
            .chartYScale(domain: yDomain)
            .chartYAxisFormatted(axisLabel)
            .chartCardStyle(colors: [
                "Weight": Color.gray,
                "Trend": Color.blue,
                "Expected range": Color.blue.opacity(0.15),
                "Goal": Color.green
            ], dates: points.compactMap { $0.actualWeight != nil ? $0.date : nil }) { date in
                popupContent(for: date)
            }
        }
    }

    @ViewBuilder
    private func popupContent(for date: Date) -> some View {
        if let point = points.first(where: { $0.date == date }) {
            if let actual = point.actualWeight {
                Text(renderWeight(kilos: actual)).font(.caption)
            }
            if let trend = point.trendWeight {
                Text("Trend: " + renderWeight(kilos: trend)).font(.caption2).foregroundStyle(.blue)
            }
            if let lower = point.expectedLower, let upper = point.expectedUpper {
                Text("Expected: \(renderWeight(kilos: lower)) – \(renderWeight(kilos: upper))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WeightChartView(points: [], goalWeight: 0)
}
