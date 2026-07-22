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

struct WeightView: View {
    @EnvironmentObject var todayLump: TodayLump
    @Binding var showingWeightGoalSheet: Bool

    let gradient = Gradient(colors: [.green, .blue])

    /// Both weekly averages are needed before the trend means anything — otherwise a first-ever weigh-in reads as an enormous "change" from a nonexistent week.
    private var haveTrendData: Bool {
        todayLump.prevWeekAvgWeight != 0 && todayLump.lastWeekAvgWeight != 0
    }

    /// Whether the user has a target to track against at all. A user whose express wish is to stay the same weight has nothing to be "on target" for.
    private var hasDeficitTarget: Bool {
        settingsObj.desiredDeficit != 0
    }

    private var trendLabel: (text: String, color: Color) {
        guard haveTrendData else { return ("No trend yet", .secondary) }
        // With no deficit/surplus goal, the user's desired trend is a band around zero — they
        // never asked to move in either direction, so neither reads as good or bad.
        guard hasDeficitTarget else {
            if todayLump.weightTrend > 0.3 { return ("Trending down", .secondary) }
            if todayLump.weightTrend < -0.3 { return ("Trending up", .secondary) }
            return ("Static", .secondary)
        }
        let downIsGood = !settingsObj.surplusMode
        if todayLump.weightTrend > 0.3 { return ("Trending down", downIsGood ? .green : .red) }
        if todayLump.weightTrend < -0.3 { return ("Trending up", downIsGood ? .red : .green) }
        return ("Static", .yellow)
    }

    private var performanceLabel: (text: String, color: Color, min: Double, max: Double)? {
        guard hasDeficitTarget,
              haveTrendData,
              todayLump.consistentlyLoggedFood,
              let standing = todayLump.trendStanding else { return nil }
        switch standing.standing {
        case .ahead:    return ("Exceeding target", .blue, standing.lower, standing.upper)
        case .behind:   return ("Off target", .yellow, standing.lower, standing.upper)
        case .onTarget: return ("On target", .green, standing.lower, standing.upper)
        }
    }
    
    var body: some View {
        if todayLump.currentWeight == 0 {
            VStack(spacing: 8) {
                Image(systemName: "scalemass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No recent weight data")
                    .font(.headline)
                Text("Log your weight to track progress toward your goal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else {
            HStack {
                VStack {
                    AccessoryCircularGauge(value: todayLump.weightGoalRemaining, range: 0...1, gradient: gradient) {
                        Text(renderWeight(kilos: todayLump.weightToday, includeSuffix: false))
                    }
                        .padding()
                        .overlay(alignment: .bottom) {
                            Text("Goal: " + renderWeight(kilos: settingsObj.weightGoal, includeSuffix: true))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                        .accessibilityLabel("Current weight")
                        .accessibilityValue("\(renderWeight(kilos: todayLump.weightToday, includeSuffix: true)), goal \(renderWeight(kilos: settingsObj.weightGoal, includeSuffix: true))")
                    
                    if let prev = todayLump.prevWeightDate,
                       let last = todayLump.lastWeightDate,
                       prev != last {
                        HStack {
                            if todayLump.weightToday < todayLump.weightYesterday {
                                Image(systemName: "arrow.down").foregroundStyle(.secondary)
                                Text(renderWeight(kilos: todayLump.changeSinceLastReading)).foregroundStyle(.secondary)
                            } else if todayLump.weightToday > todayLump.weightYesterday {
                                Image(systemName: "arrow.up").foregroundStyle(.secondary)
                                Text(renderWeight(kilos: -todayLump.changeSinceLastReading)).foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "equal.circle").foregroundStyle(.secondary)
                                Text("-").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading) {
                    HStack {
                        VStack(alignment: .leading) {
                            StatusHeadline(text: trendLabel.text, color: trendLabel.color)
                            HStack {
                                if !haveTrendData {
                                    Text("Weigh in for a couple of weeks to see your weight trend.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                } else if todayLump.weightTrend > 0 {
                                    Text("\(renderWeight(kilos: todayLump.weightTrend)) down on the previous week")
                                        .foregroundColor(.secondary)
                                } else if todayLump.weightTrend < 0 {
                                    Text("\(renderWeight(kilos: -todayLump.weightTrend)) up on the previous week")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No change from the previous week")
                                }
                            }
                        }.padding(.leading)
                        if hasDeficitTarget {
                            Divider()
                            VStack(alignment: .leading) {
                                if let performance = performanceLabel {
                                    StatusHeadline(text: performance.text, color: performance.color)
                                    Text("Expected\n\(renderWeight(kilos: performance.min)) - \(renderWeight(kilos: performance.max))")
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                } else {
                                    Text("Log your food regularly to see how you're tracking against your target.")
                                        .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }
                    HStack {
                        Spacer()
                        if settingsObj.weightGoal == 0 {
                            Text("You don't have a weight goal set.")
                        } else if todayLump.weightGoalMet {
                            VStack {
                                Text("🎉 **Goal reached!** Nice work.")
                                    .multilineTextAlignment(.center)
                                Button("Set a new goal", systemImage: "target") {
                                    showingWeightGoalSheet = true
                                }.buttonStyle(.borderedProminent)
                            }
                        } else if todayLump.hasGoalTimeEstimate {
                            let daysToGoal = settingsObj.surplusMode
                                ? getDaysToGain(weight: todayLump.weightToGo, surplus: todayLump.goalProjectionDeficit)
                                : getDaysToLose(weight: todayLump.weightToGo, deficit: todayLump.goalProjectionDeficit)
                            Text("Expect to hit goal in **\(formatDuration(days: daysToGoal))**")
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        } else if todayLump.movingAwayFromGoal {
                            Text(settingsObj.surplusMode
                                 ? "**In caloric deficit** over past week"
                                 : "**In caloric surplus** over past week")
                        } else {
                            Text("Log your food regularly to get predictions.")
                                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
