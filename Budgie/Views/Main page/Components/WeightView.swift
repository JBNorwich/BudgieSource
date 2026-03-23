//
//  WeightView.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 22/03/2026.
//

import SwiftUI

struct WeightView: View {
    @EnvironmentObject var todayLump: TodayLump
    
    let gradient = Gradient(colors: [.green, .blue])
    
    var body: some View {
        HStack {
            VStack {
                Gauge(value: todayLump.weightGoalLeft, in: 0...1) {
                } currentValueLabel: {
                    Text(roundDoubleWeight(input: todayLump.weightToday).formatted())
                } minimumValueLabel: {
                    Text(settingsObj.weightGoal.formatted())
                } maximumValueLabel: {
                    Text("")
                }.gaugeStyle(.accessoryCircular)
                    .tint(gradient)
                    .scaleEffect(1.5)
                    .padding()
                    .animation(.easeInOut, value: todayLump.weightGoalLeft)
                if todayLump.weightYesterday != 0 {
                    HStack {
                        if(todayLump.weightToday < todayLump.weightYesterday) {
                            Image(systemName: "arrow.down")
                                .foregroundStyle(.secondary)
                            Text(todayLump.lostInDay.formatted())
                                .foregroundStyle(.secondary)
                        } else if todayLump.weightToday > todayLump.weightYesterday {
                            Image(systemName: "arrow.up")
                                .foregroundStyle(.secondary)
                            Text(todayLump.lostInDay.formatted())
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "equal.circle")
                                .foregroundStyle(.secondary)
                            Text("-")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Divider()
            VStack {
                HStack {
                    VStack {
                        if todayLump.weightTrend > 0.3 {
                            Text("**Trending down**")
                                .foregroundColor(.green)
                        } else if todayLump.weightTrend < -0.3 {
                            Text("**Trending up**")
                                .foregroundColor(.red)
                        } else {
                            Text("**Static**")
                                .foregroundColor(.yellow)
                        }
                        HStack {
                            if todayLump.weightTrend > 0 {
                                //lost weight
                                Text("\(todayLump.weightTrend.formatted())kg down on last week's average")
                                    .foregroundColor(.secondary)
                            } else if todayLump.weightTrend < 0 {
                                //gained weight
                                Text("\(todayLump.weightTrend.formatted())kg up on last week's average")
                            } else {
                                Text("No change from last week's average")
                            }
                        }
                    }
                    Divider()
                    VStack {
                        if todayLump.performanceAgainstWeightTrend > 1.5 {
                            Text("**Exceeding target**")
                                .foregroundColor(.blue)
                        } else if todayLump.performanceAgainstWeightTrend < 0.5 {
                            Text("**Off targets**")
                                .foregroundColor(.yellow)
                        } else {
                            Text("**On target**")
                                .foregroundColor(.green)
                        }
                        Text("Expected \(roundDoubleWeight(input: todayLump.expectedWeightLossAtRealDeficit).formatted())kg")
                            .foregroundColor(.secondary)
                        Text("Real deficit: \(todayLump.realDeficit.formatted())")
                            .foregroundColor(.secondary)
                    }
                }
                HStack {
                    Spacer()
                    if settingsObj.weightGoal != 0 {
                        if todayLump.averageDeficit > 0 {
                            Text("Expect to hit goal in **\(formatDuration(days: getDaysToLose(weight: todayLump.weightToGo, deficit: todayLump.realDeficit)))**")
                        } else {
                            Text("**In caloric surplus** over past week")
                        }
                    } else {
                        Text("You don't have a weight goal set.")
                    }
                    Spacer()
                }
            }
        }
    }
}
