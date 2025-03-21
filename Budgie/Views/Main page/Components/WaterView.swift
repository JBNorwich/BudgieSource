//
//  Untitled.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 20/03/2025.
//
import SwiftUI

struct WaterView: View {
    @Binding var todayLump: TodayLump
    
    let gradient = Gradient(colors: [.white, .blue])
    
    var body: some View {
        VStack {
            Spacer()
            Gauge(value: todayLump.waterGoalDone, in: 0...1) {
            } currentValueLabel: {
                Text("\(todayLump.waterToday.formatted())ml")
            } minimumValueLabel: {
                Text("")
            } maximumValueLabel: {
                Text("")
            }.gaugeStyle(.accessoryCircular)
                .tint(gradient)
                .scaleEffect(1.5)
                .padding(.top, 10)
            Spacer()
        }
    }
}
