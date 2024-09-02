//
//  GaugeView.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 29/08/2024.
//

import SwiftUI

struct GaugeView: View {
    @Binding var dataLump: TodayLump
    let gradient = Gradient(colors: [.blue, .green, .yellow, .red])
    
    var body: some View {
        HStack {
            VStack {
                Gauge(value: dataLump.progressAgainstTime, in: 0...2) {
                } currentValueLabel: {
                    if dataLump.gaugeNumber > 0 {
                        Text("+" + dataLump.gaugeNumber.formatted() + "%")
                    } else {
                        Text("-" + negate(number: dataLump.gaugeNumber).formatted() + "%")
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
            }
            Divider()
            VStack {
                if minutesIntoDay() < 540 && dataLump.leftToEat > 0 {
                    Text("Good morning! You have **\(dataLump.totalBudgetRem)kcal** left in your overall budget today, and can eat \(dataLump.leftToEat) right now.")
                } else {
                    if dataLump.budgetDiffByTime > 49 {
                        if dataLump.totalBudgetRem < 0 {
                            Text("You've gone over your total daily budget by **\(negate(number: dataLump.totalBudgetRem))kcal** - that's OK, it happens sometimes.")
                        } else if dataLump.totalBudgetRem < 500 {
                            Text("Be careful - you've only got **\( dataLump.totalBudgetRem)kcal** left in your budget for the rest of the day.")
                        } else {
                            Text("You have **\(dataLump.totalBudgetRem)kcal** left in your budget overall today.")
                        }
                    } else if dataLump.budgetDiffByTime < -500 {
                        Text("You're way below your target for this time of day! You can eat **\(dataLump.leftToEat)kcal** right now, and have **\(dataLump.totalBudgetRem)kcal** left in your budget overall.")
                    } else if dataLump.budgetDiffByTime < -50 {
                        Text("It looks like you're below your target for this time of day; you can eat **\(dataLump.normalisedLTE)kcal** right now, and have **\(dataLump.totalBudgetRem)kcal** left in your budget overall.")
                    } else {
                        Text("It looks like you're about on target right now! You have **\(dataLump.leftToEat)kcal** left to eat right now and **\(dataLump.totalBudgetRem)kcal** left in your budget overall.")
                    }
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
            GaugeView(dataLump: $lump)
        }
    }
    
    return Preview()
}
