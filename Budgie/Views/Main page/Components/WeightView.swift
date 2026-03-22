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
            }
            Divider()
            VStack {
                if settingsObj.weightGoal != 0 {
                    Text("Based on your past week's average deficit of \(todayLump.averageDeficit.formatted()), I think it'll take you \(formatDuration(days: todayLump.daysToWeightGoal)) to reach your goal.")
                } else {
                    Text("You don't have a weight goal set.")
                }
                if settingsObj.weightGoal != 0 {
                    Text("If every day was like yesterday, you'd reach your goal in \(formatDuration(days: getDaysToLose(weight: todayLump.weightToGo, deficit: todayLump.yesterdayDeficit)))!")
                }
            }
        }
    }
}
