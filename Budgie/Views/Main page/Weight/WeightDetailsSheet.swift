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
    
    var body: some View {
         NavigationStack {
             ScrollView {
                 GroupBox(label: Label("Progress", systemImage: "gauge.with.needle")) {
                     HStack{
                         VStack {
                             Text("WEEK BEFORE LAST")
                                 .multilineTextAlignment(.leading)
                                 .font(.caption)
                             Text("\(todayLump.prevWeekAvgWeight.formatted())kg")
                                 .font(.largeTitle)
                             Text("AVERAGE")
                                 .multilineTextAlignment(.leading)
                                 .font(.caption)
                                 .foregroundStyle(.secondary)
                             
                         }.frame(minWidth: 0, maxWidth: .infinity)
                         Divider()
                         VStack {
                             Text("LAST WEEK")
                                 .multilineTextAlignment(.leading)
                                 .font(.caption)
                             Text("\(todayLump.lastWeekAvgWeight.formatted())kg")
                                 .font(.largeTitle)
                             Text("AVERAGE")
                                 .multilineTextAlignment(.leading)
                                 .font(.caption)
                                 .foregroundStyle(.secondary)
                         }.frame(minWidth: 0, maxWidth: .infinity)
                         Divider()
                         VStack {
                             Text("LAST WEIGH IN")
                                 .multilineTextAlignment(.leading)
                                 .font(.caption)
                             if todayLump.weightToday != 0 {
                                 Text("\(todayLump.weightToday.formatted())kg")
                                     .font(.largeTitle)
                             } else {
                                 Text("--")
                                     .font(.largeTitle)
                                     .fontWeight(.bold)
                                     .foregroundStyle(.secondary)
                             }
                             if todayLump.lastWeightDate != nil {
                                 Text(todayLump.lastWeightDate!.formatted(date: .abbreviated, time: .omitted).uppercased())
                                     .multilineTextAlignment(.leading)
                                     .font(.caption)
                                     .foregroundStyle(.secondary)
                             } else {
                                 Text("NO DATA")
                                     .multilineTextAlignment(.leading)
                                     .font(.caption)
                                     .foregroundStyle(.secondary)
                             }
                         }.frame(minWidth: 0, maxWidth: .infinity)
                     }
                 }
                 GroupBox(label: Label("Predictions", systemImage: "chart.bar.xaxis.descending")) {
                     VStack {
                         HStack {
                             VStack {
                                 Text("RECORDED DAILY DEFICIT")
                                     .multilineTextAlignment(.leading)
                                     .font(.caption)
                                 Text("\(todayLump.averageDeficit.formatted())kcal")
                                     .font(.largeTitle)
                                 Text("OVER LAST WEEK")
                                     .multilineTextAlignment(.leading)
                                     .font(.caption)
                                     .foregroundStyle(.secondary)
                             }.frame(minWidth: 0, maxWidth: .infinity)
                             Divider()
                             VStack {
                                 Text("This is your daily deficit, based on the data available.")
                             }.frame(minWidth: 0, maxWidth: .infinity)
                         }
                         HStack {
                             VStack {
                                 Text("EXPECTED LOSS")
                                     .multilineTextAlignment(.leading)
                                     .font(.caption)
                                 Text("\(todayLump.expectedWeightLossAtRealDeficit.formatted())kg")
                                     .font(.largeTitle)
                                 Text("AT THIS DEFICIT")
                                     .multilineTextAlignment(.leading)
                                     .font(.caption)
                                     .foregroundStyle(.secondary)
                             }.frame(minWidth: 0, maxWidth: .infinity)
                             Divider()
                             VStack {
                                 Text("This is how much weight you'd expect to lose at that deficit.")
                             }.frame(minWidth: 0, maxWidth: .infinity)
                         }
                         HStack {
                             VStack {
                                 Text("ACTUAL LOSS")
                                     .multilineTextAlignment(.leading)
                                     .font(.caption)
                                 Text("\(todayLump.weightTrend.formatted())kg")
                                     .font(.largeTitle)
                                 Text("OVER LAST WEEK")
                                     .multilineTextAlignment(.leading)
                                     .font(.caption)
                                     .foregroundStyle(.secondary)
                             }.frame(minWidth: 0, maxWidth: .infinity)
                             Divider()
                             VStack {
                                 Text("This is your actual weight loss trend.")
                             }.frame(minWidth: 0, maxWidth: .infinity)
                         }
                         HStack {
                             VStack {
                                 Text("REAL DEFICIT")
                                     .multilineTextAlignment(.leading)
                                     .font(.caption)
                                 Text("\(todayLump.realDeficit.formatted())kcal")
                                     .font(.largeTitle)
                                 Text("PER DAY")
                                     .multilineTextAlignment(.leading)
                                     .font(.caption)
                                     .foregroundStyle(.secondary)
                             }.frame(minWidth: 0, maxWidth: .infinity)
                             Divider()
                             VStack {
                                 Text("This is the deficit your progress suggests you're actually at.")
                             }.frame(minWidth: 0, maxWidth: .infinity)
                         }
                     }
                 }
             }
        }
         .padding()
        .navigationTitle("Weight details")
    }
}
