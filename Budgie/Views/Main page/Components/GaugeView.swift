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
                    Text("Good morning! You have **\(dataLump.totalBudgetRem)kcal** left in your overall budget today, and can eat \(dataLump.leftToEat)kcal right now.")
                } else {
                    if dataLump.gaugeNumber > 10 {
                        if dataLump.totalBudgetRem < 0 {
                            Text("You've gone over your total daily budget by **\(negate(number: dataLump.totalBudgetRem))kcal** - that's OK, it happens sometimes.")
                        } else if dataLump.totalBudgetRem < 500 {
                            Text("Be careful - you've only got **\( dataLump.totalBudgetRem)kcal** left in your budget for the rest of the day.")
                        } else {
                            Text("You're a little bit ahead of where you should be right now, but no sweat - you have **\(dataLump.totalBudgetRem)kcal** left in your budget overall today.")
                        }
                    } else if dataLump.gaugeNumber < -5 {
                        if dataLump.gaugeNumber < -50 {
                            Text("You're way below your target for this time of day! You can eat **\(dataLump.leftToEat)kcal** right now, and have **\(dataLump.totalBudgetRem)kcal** left in your budget overall.")
                        } else if dataLump.gaugeNumber < -25 {
                            Text("It looks like you're below your target for this time of day; you can eat **\(dataLump.normalisedLTE)kcal** right now, and have **\(dataLump.totalBudgetRem)kcal** left in your budget overall.")
                        } else {
                            Text("You're below your target right now for the time of day, and you can eat **\(dataLump.normalisedLTE)kcal** right now. Your budget has **\(dataLump.totalBudgetRem)kcal** left.")
                        }
                    } else {
                        if dataLump.leftToEat > 0 {
                            if dataLump.totalBudgetRem - dataLump.leftToEat < 100 {
                                Text("It looks like you're more or less on target! You have **\(dataLump.totalBudgetRem)kcal** left in your budget for the rest of the day.")
                            } else {
                                Text("It looks like you're more or less on target! You have **\(dataLump.leftToEat)kcal** you can eat right now and **\(dataLump.totalBudgetRem)kcal** left in your budget overall.")
                            }
                        } else {
                            Text("It looks like you're more or less on target, but you don't have anything left to eat right now. **\(dataLump.totalBudgetRem)kcal** is left in your budget overall.")
                        }
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
