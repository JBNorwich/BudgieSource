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

    private var trendLabel: (text: String, color: Color) {
        let downIsGood = !settingsObj.surplusMode
        if todayLump.weightTrend > 0.3 { return ("Trending down", downIsGood ? .green : .red) }
        if todayLump.weightTrend < -0.3 { return ("Trending up", downIsGood ? .red : .green) }
        return ("Static", .yellow)
    }

    private var performanceLabel: (text: String, color: Color)? {
        guard !settingsObj.surplusMode,
              todayLump.consistentlyLoggedFood,
              let performance = todayLump.performanceAgainstWeightTrend else { return nil }
        if performance > 1.5 { return ("Exceeding target", .blue) }
        if performance < 0.5 { return ("Off target", .yellow) }
        return ("On target", .green)
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
                    Gauge(value: todayLump.weightGoalRemaining, in: 0...1) {
                    } currentValueLabel: {
                        Text(renderWeight(kilos: todayLump.weightToday, includeSuffix: false))
                    }.gaugeStyle(.accessoryCircular)
                        .tint(gradient)
                        .scaleEffect(1.5)
                        .padding()
                        .animation(.easeInOut, value: todayLump.weightGoalRemaining)
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
                VStack {
                    HStack {
                        VStack {
                            Text("**\(trendLabel.text)**").foregroundColor(trendLabel.color)
                            HStack {
                                if todayLump.weightTrend > 0 {
                                    Text("\(renderWeight(kilos: todayLump.weightTrend)) down on the previous week")
                                        .foregroundColor(.secondary)
                                } else if todayLump.weightTrend < 0 {
                                    Text("\(renderWeight(kilos: -todayLump.weightTrend)) up on the previous week")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No change from the previous week")
                                }
                            }.padding(.leading)
                        }
                        if !settingsObj.surplusMode {
                            Divider()
                            VStack {
                                if let performance = performanceLabel {
                                    Text("**\(performance.text)**").foregroundColor(performance.color)
                                    Text("Expected \(renderWeight(kilos: todayLump.expectedWeightLossAtRealDeficit))")
                                        .foregroundColor(.secondary)
                                    Text("Real deficit: \(todayLump.realDeficit.formatted())")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Log your food regularly to see how you're tracking against your target.")
                                        .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
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
                        } else {
                            Text(settingsObj.surplusMode
                                 ? "**In caloric deficit** over past week"
                                 : "**In caloric surplus** over past week")
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
