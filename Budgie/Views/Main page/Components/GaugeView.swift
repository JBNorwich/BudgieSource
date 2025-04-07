//
//  GaugeView.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 29/08/2024.
//

import SwiftUI

struct GaugeView: View {
    @EnvironmentObject var todayLump: TodayLump
    let gradient = Gradient(colors: [.blue, .green, .yellow, .red])
    
    var body: some View {
        HStack {
            VStack {
                Gauge(value: todayLump.progressAgainstTarget, in: 0...2) {
                } currentValueLabel: {
                    if todayLump.gaugeNumber > 0 {
                        Text("+" + todayLump.gaugeNumber.formatted() + "%")
                    } else {
                        Text("-" + negate(number: todayLump.gaugeNumber).formatted() + "%")
                    }
                } minimumValueLabel: {
                    Text("")
                        .foregroundColor(.teal)
                } maximumValueLabel: {
                    Text("")
                        .foregroundColor(.red)
                }.gaugeStyle(.accessoryCircular)
                    .tint(gradient)
                    .padding()
                    .animation(.easeInOut, value: todayLump.progressToday)
            }
            Divider()
            VStack {
                Text("**\(todayLump.eatenCalories)** cals in - **\(todayLump.calsOutNow)** cals out")
                    .multilineTextAlignment(.leading)
                if todayLump.totalBudgetRem > -1 {
                    Text("**\(todayLump.totalBudgetRem.formatted())** cals left in budget today")
                        .multilineTextAlignment(.leading)
                } else {
                    Text("**\((-todayLump.totalBudgetRem).formatted())** cals over budget")
                        .multilineTextAlignment(.leading)
                }
                
                if settingsObj.hideTodayInDetail == true && todayLump.activeEstimated == true {
                    Divider()
                    Text("Your active calories are estimated, so your budget doesn't reflect your real activity.")
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}

#Preview {
    
    
    struct Preview: View {
        @State var lump = TodayLump()
        
        init() {
            // time is hardcoded to midday
            lump.eatenCalories = 2300
            lump.projectedActive = 250
            lump.projectedBasal = 1200
            lump.activeCalories = 250
            lump.basalCalories = 1200
            // at exactly 50% of budget
            // budget will be 2400
        }
        
        var body: some View {
            GaugeView().environmentObject(lump)
        }
    }
    
    return Preview()
}
