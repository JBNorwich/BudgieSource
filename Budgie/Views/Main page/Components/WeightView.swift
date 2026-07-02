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

// ... licence header unchanged ...
import SwiftUI

struct WeightView: View {
    @EnvironmentObject var todayLump: TodayLump
    @Binding var showingWeightGoalSheet: Bool

    let gradient = Gradient(colors: [.green, .blue])

    private var trendLabel: (text: String, color: Color) {
        if todayLump.weightTrend > 0.3 { return ("Trending down", .green) }
        if todayLump.weightTrend < -0.3 { return ("Trending up", .red) }
        return ("Static", .yellow)
    }

    private var performanceLabel: (text: String, color: Color)? {
        guard todayLump.consistentlyLoggedFood else { return nil }
        if todayLump.performanceAgainstWeightTrend > 1.5 { return ("Exceeding target", .blue) }
        if todayLump.performanceAgainstWeightTrend < 0.5 { return ("Off target", .yellow) }
        return ("On target", .green)
    }

    var body: some View {
        HStack {
            VStack {
                Gauge(value: todayLump.weightGoalRemaining, in: 0...1) {
                } currentValueLabel: {
                    Text(renderWeight(kilos: todayLump.weightToday, includeSuffix: false))
                } minimumValueLabel: {
                    Text(renderWeight(kilos: settingsObj.weightGoal, includeSuffix: false))
                } maximumValueLabel: {
                    Text("")
                }.gaugeStyle(.accessoryCircular)
                    .tint(gradient)
                    .scaleEffect(1.5)
                    .padding()
                    .animation(.easeInOut, value: todayLump.weightGoalRemaining)
                if todayLump.weightYesterday != 0 {
                    HStack {
                        if(todayLump.weightToday < todayLump.weightYesterday) {
                            Image(systemName: "arrow.down").foregroundStyle(.secondary)
                            Text(renderWeight(kilos: todayLump.lostInDay)).foregroundStyle(.secondary)
                        } else if todayLump.weightToday > todayLump.weightYesterday {
                            Image(systemName: "arrow.up").foregroundStyle(.secondary)
                            Text(renderWeight(kilos: -todayLump.lostInDay)).foregroundStyle(.secondary)
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
                                Text("\(renderWeight(kilos: todayLump.weightTrend)) down on last week's average")
                                    .foregroundColor(.secondary)
                            } else if todayLump.weightTrend < 0 {
                                Text("\(renderWeight(kilos: -todayLump.weightTrend)) up on last week's average")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No change from last week's average")
                            }
                        }
                    }
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
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
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
                    } else if todayLump.averageDeficit > 0 {
                        Text("Expect to hit goal in **\(formatDuration(days: getDaysToLose(weight: todayLump.weightToGo, deficit: todayLump.realDeficit)))**")
                    } else {
                        Text("**In caloric surplus** over past week")
                    }
                    Spacer()
                }
            }
        }
    }
}
