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

struct WeightDetailsSheet: View {
    @EnvironmentObject var todayLump: TodayLump

    private var surplus: Bool { settingsObj.surplusMode }

    /// The recorded kcal rate in the direction of the user's goal (deficit when losing,
    /// surplus when gaining), so the figure reads positively when they're on plan.
    private var recordedGoalRate: Int { surplus ? -todayLump.averageDeficit : todayLump.averageDeficit }
    /// Expected weekly change in the goal direction (kg).
    private var expectedChange: Double { surplus ? -todayLump.expectedWeightLossAtRealDeficit : todayLump.expectedWeightLossAtRealDeficit }
    /// Actual weekly change in the goal direction (kg).
    private var actualChange: Double { surplus ? -todayLump.weightTrend : todayLump.weightTrend }

    private func kcalDisplay(_ value: Int) -> String { "\(value.formatted())kcal" }
    private func weightDisplay(_ kilos: Double) -> String {
        renderWeight(kilos: kilos.isNaN ? 0 : kilos)
    }

    struct StatColumn: View {
        let title: String
        /// Kilograms; rendered in the user's chosen weight unit.
        let value: Double
        let subtitle: String

        private var hasData: Bool { !value.isZero && !value.isNaN }

        var body: some View {
            VStack {
                Text(title)
                    .multilineTextAlignment(.leading)
                    .font(.caption)
                if hasData {
                    Text(renderWeight(kilos: value))
                        .font(.largeTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)   // "12st 7lb" is wider than "79.8kg"
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("-")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("NO DATA")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
        }
    }

    struct PredictionRow: View {
        let title: String
        let display: String
        let subtitle: String
        let description: String
        let last: Bool

        var body: some View {
            GridRow {
                VStack {
                    Text(title).font(.caption)
                    Text(display)
                        .font(.largeTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }.frame(minWidth: 0, maxWidth: .infinity)
                Text(description)
                    .frame(minWidth: 0, maxWidth: .infinity)
            }
            if !last { Divider() }
       }
    }

    var body: some View {
         NavigationStack {
             ScrollView {
                GroupBox(label: Label("Progress", systemImage: "gauge.with.needle")) {
                     HStack {
                         StatColumn(title: "WEEK BEFORE", value: todayLump.prevWeekAvgWeight, subtitle: "AVERAGE")
                         Divider()
                         StatColumn(title: "LAST WEEK", value: todayLump.lastWeekAvgWeight, subtitle: "AVERAGE")
                         Divider()
                         StatColumn(title: "LAST WEIGH IN", value: todayLump.weightToday, subtitle: todayLump.lastWeightDate?.formatted(date: .abbreviated, time: .omitted).uppercased() ?? "NO DATA")
                     }
                 }
                 GroupBox(label: Label("Predictions", systemImage: "chart.bar.xaxis.descending")) {
                     Grid {
                         PredictionRow(title: surplus ? "RECORDED DAILY SURPLUS" : "RECORDED DAILY DEFICIT",
                                       display: kcalDisplay(recordedGoalRate),
                                       subtitle: "OVER LAST WEEK",
                                       description: "This is your daily \(surplus ? "surplus" : "deficit"), based on the data available.",
                                       last: false)
                         PredictionRow(title: surplus ? "EXPECTED GAIN" : "EXPECTED LOSS",
                                       display: weightDisplay(expectedChange),
                                       subtitle: surplus ? "AT THIS SURPLUS" : "AT THIS DEFICIT",
                                       description: "This is how much weight you'd expect to \(surplus ? "gain at that surplus" : "lose at that deficit").",
                                       last: false)
                         PredictionRow(title: surplus ? "ACTUAL GAIN" : "ACTUAL LOSS",
                                       display: weightDisplay(actualChange),
                                       subtitle: "OVER LAST WEEK",
                                       description: "This is your actual weight \(surplus ? "gain" : "loss") trend.",
                                       last: false)
                         PredictionRow(title: surplus ? "REAL SURPLUS" : "REAL DEFICIT",
                                       display: kcalDisplay(todayLump.realDeficit),
                                       subtitle: "PER DAY",
                                       description: "This is the \(surplus ? "surplus" : "deficit") your progress suggests you're actually at.",
                                       last: true)
                        }.padding()
                 }
             }
        }
         .padding()
        .navigationTitle("Weight details")
    }
}
