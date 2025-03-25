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
                if minutesIntoDay() < 540 && todayLump.leftToEat > 0 {
                    Text("Good morning! You have **\(todayLump.totalBudgetRem)kcal** left in your overall budget today, and can eat \(todayLump.leftToEat)kcal right now.")
                } else {
                    if todayLump.gaugeNumber > 10 {
                        if todayLump.totalBudgetRem < 0 {
                            Text("You've gone over your total daily budget by **\(negate(number: todayLump.totalBudgetRem))kcal** - that's OK, it happens sometimes.")
                        } else if todayLump.totalBudgetRem < 500 {
                            Text("Be careful - you've only got **\( todayLump.totalBudgetRem)kcal** left in your budget for the rest of the day.")
                        } else {
                            Text("You're a little bit ahead of where you should be right now, but no sweat - you have **\(todayLump.totalBudgetRem)kcal** left in your budget overall today.")
                        }
                    } else if todayLump.gaugeNumber < -5 {
                        if todayLump.gaugeNumber < -50 {
                            Text("You're way below your target for this time of day! You can eat **\(todayLump.leftToEat)kcal** right now, and have **\(todayLump.totalBudgetRem)kcal** left in your budget overall.")
                        } else if todayLump.gaugeNumber < -25 {
                            Text("It looks like you're below your target for this time of day; you can eat **\(todayLump.normalisedLTE)kcal** right now, and have **\(todayLump.totalBudgetRem)kcal** left in your budget overall.")
                        } else {
                            Text("You're below your target right now for the time of day, and you can eat **\(todayLump.normalisedLTE)kcal** right now. Your budget has **\(todayLump.totalBudgetRem)kcal** left.")
                        }
                    } else {
                        if todayLump.leftToEat > 0 {
                            if todayLump.totalBudgetRem - todayLump.leftToEat < 100 {
                                Text("It looks like you're more or less on target! You have **\(todayLump.totalBudgetRem)kcal** left in your budget for the rest of the day.")
                            } else {
                                Text("It looks like you're more or less on target! You have **\(todayLump.leftToEat)kcal** you can eat right now and **\(todayLump.totalBudgetRem)kcal** left in your budget overall.")
                            }
                        } else {
                            Text("It looks like you're more or less on target, but you don't have anything left to eat right now. **\(todayLump.totalBudgetRem)kcal** is left in your budget overall.")
                        }
                    }
                }
                
                if settingsObj.hideTodayInDetail == true {
                    Divider()
                    VStack {
                        if todayLump.activeEstimated == true {
                            Text("Your active calories are estimated, so your budget doesn't reflect your real activity.")
                        }
                        HStack {
                            Text("**Cals in**: \(todayLump.eatenCalories)")
                            Spacer()
                            Text("**Cals out**: \(todayLump.calsOutNow)")
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
            GaugeView().environmentObject(lump)
        }
    }
    
    return Preview()
}
