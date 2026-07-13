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
    
    private var haveTrendData: Bool {
        todayLump.prevWeekAvgWeight != 0 && todayLump.lastWeekAvgWeight != 0
    }
    
    @State private var showingHelp: Bool = false

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
                                   display: haveTrendData ? weightDisplay(actualChange) : "–",
                                   subtitle: haveTrendData ? "OVER LAST WEEK" : "NO DATA",
                                   description: "This is your actual weight \(surplus ? "gain" : "loss") trend.",
                                   last: false)
                     PredictionRow(title: surplus ? "REAL SURPLUS" : "REAL DEFICIT",
                                   display: todayLump.performanceAgainstWeightTrend != nil ? kcalDisplay(todayLump.realDeficit) : "–",
                                   subtitle: todayLump.performanceAgainstWeightTrend != nil ? "PER DAY" : "NO DATA",
                                   description: "This is the \(surplus ? "surplus" : "deficit") your progress suggests you're actually at.",
                                   last: true)
                    }.padding()
             }
             HStack {
                 Spacer()
                 Button("Learn more") {
                     showingHelp = true
                 }.buttonStyle(.borderedProminent)
                     .padding()
                 Spacer()
             }
         }
         .padding()
         .navigationTitle("Weight details")
         .sheet(isPresented: $showingHelp) {
             WeightExplainerSheet(isDisplayed: $showingHelp)
                 .presentationDragIndicator(.visible)
         }
    }
}

struct WeightExplainerSheet: View {
    @Binding var isDisplayed: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                GroupBox {
                    Text("**Recorded daily deficit/surplus** is your average daily deficit (or surplus) over the past week. This is used to calculate your expected weight trend, and is based on the data that Budgie Diet has available to it (including your logged food).")
                }
                GroupBox {
                    Text("**Expected loss/gain** is how much weight would be expected to be lost (or gained) over a week at that level. As a rule of thumb, \(renderWeight(kilos: 1)) of fat contains 7,700kcal, so you'd need to burn that much to lose that much weight - but this isn't precise. (Bulking, i.e. gaining weight by building muscle, is different.)\n\nIt's generally best to take this figure with a pinch of salt, because your weight can fluctuate for reasons outside your control, such as water retention, menstrual cycles, and even your metabolism. It's also possible to gain weight without gaining fat (or lose weight without losing muscle), and the number is just an estimate. Budgie Diet shows a range on the Today screen that takes account of this, but the details screen shows the exact number.")
                }
                GroupBox {
                    Text("**Actual gain/loss** is the difference between the past 7 days' average weight, and the average weight of the week before. This is shown, rather than just a straight difference between your weight today and your weight one week ago, for the reason given above; your weight can fluctuate from day to day due to various factors, and comparing averages smooths this out and gives you a clearer picture of your actual progress.")
                }
                GroupBox {
                    Text("**Real deficit/surplus** is, using the same sort of formula as \"Expected loss/gain\", how much your weight trend suggests you've actually had as a deficit (or surplus). You shouldn't pay too much attention to this, since as above, your weight can change for many reasons outside of just the calories you eat, and you might be doing just fine - for instance, it's common for people who are exercising to build a little bit of muscle at the same time as they lose fat, rather than just losing weight as fat.")
                }
                GroupBox {
                    Text("**On target**, **off target** and **exceeding target** on the Today screen compares your actual weekly change against the range Budgie Diet would expect from your recorded deficit/surplus. Because your weight fluctuates, being on target is a band rather than a single figure: land inside it and you're tracking as the numbers predict, while off target or exceeding target simply mean you're moving a little slower or faster than expected. It's only a guide — plenty of everyday things move the scale, so one week outside the band on its own doesn't tell you much.")
                }
            }
            .navigationTitle("About weight details")
            .navigationBarTitleDisplayMode(.inline)
            
        }.padding()
    }
}


#Preview {
    struct Preview: View {
        @State var dummyData: TodayLump = {
            let lump = TodayLump()
            lump.prevWeekAvgWeight = 82.4
            lump.lastWeekAvgWeight = 81.9
            lump.weightToday = 81.7
            lump.lastWeightDate = Date()
            lump.averageDeficit = 450
            return lump
        }()

        var body: some View {
            NavigationStack {
                WeightDetailsSheet().environmentObject(dummyData)
            }
        }
    }

    return Preview()
}
