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
    
    struct StatColumn: View {
        let title: String
        let value: Double
        let unit: String
        let subtitle: String

        private var hasData: Bool { !value.isZero && !value.isNaN }

        var body: some View {
            VStack {
                Text(title)
                    .multilineTextAlignment(.leading)
                    .font(.caption)
                if hasData {
                    Text("\(value.formatted())\(unit)")
                        .font(.largeTitle)
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
        let value: Double
        let unit: String
        let subtitle: String
        let description: String
        let last: Bool

        var body: some View {
            GridRow {
                VStack {
                    Text(title).font(.caption)
                    !value.isNaN
                    ? Text("\(value.formatted())\(unit)").font(.largeTitle)
                    : Text("0"+unit).font(.largeTitle)
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
                         StatColumn(title: "WEEK BEFORE", value: todayLump.prevWeekAvgWeight, unit: "kg", subtitle: "AVERAGE")
                         Divider()
                         StatColumn(title: "LAST WEEK", value: todayLump.lastWeekAvgWeight, unit: "kg", subtitle: "AVERAGE")
                         Divider()
                         StatColumn(title: "LAST WEIGH IN", value: todayLump.weightToday, unit: "kg", subtitle: todayLump.lastWeightDate?.formatted(date: .abbreviated, time: .omitted).uppercased() ?? "NO DATA")
                     }
                 }
                 GroupBox(label: Label("Predictions", systemImage: "chart.bar.xaxis.descending")) {
                     Grid {
                         PredictionRow(title: "RECORDED DAILY DEFICIT", value: Double(todayLump.averageDeficit), unit: "kcal", subtitle: "OVER LAST WEEK", description: "This is your daily deficit, based on the data available.", last: false)
                         PredictionRow(title: "EXPECTED LOSS", value: todayLump.expectedWeightLossAtRealDeficit, unit: "kg", subtitle: "AT THIS DEFICIT", description: "This is how much weight you'd expect to lose at that deficit.", last: false)
                         PredictionRow(title: "ACTUAL LOSS", value: todayLump.weightTrend, unit: "kg", subtitle: "OVER LAST WEEK", description: "This is your actual weight loss trend.", last: false)
                         PredictionRow(title: "REAL DEFICIT", value: Double(todayLump.realDeficit), unit: "kcal", subtitle: "PER DAY", description: "This is the deficit your progress suggests you're actually at.", last: true)
                        }.padding()
                 }
             }
        }
         .padding()
        .navigationTitle("Weight details")
    }
}
