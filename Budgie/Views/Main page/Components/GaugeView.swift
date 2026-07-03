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
                    } else if todayLump.gaugeNumber < 0 {
                        Text("-" + (-todayLump.gaugeNumber).formatted() + "%")
                    } else {
                        Text("0%")
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
                HStack {
                    if (todayLump.progressAgainstTarget < 0.95) {
                        Text("**Below target**")
                            .foregroundColor(.blue)
                    } else if todayLump.progressAgainstTarget > 1.05 {
                        Text("**Above target**")
                            .foregroundColor(.red)
                    } else {
                        Text("**On target**")
                            .foregroundColor(.teal)
                    }
                    Spacer()
                }
                HStack {
                    Text("**\(todayLump.eatenCalories)** cals in - **\(todayLump.calsOutNow)** cals out")
                    Spacer()
                }
                HStack {
                    todayLump.totalBudgetRem > -1
                        ? Text("**\(todayLump.totalBudgetRem.formatted())** cals left in budget today")
                        : Text("**\((-todayLump.totalBudgetRem).formatted())** cals over budget")
                    Spacer()
                }
                if settingsObj.hideTodayInDetail == true && (todayLump.activeEstimated || todayLump.basalEstimated) {
                    Divider()
                    HStack {
                        Text("Some of your calorie burn figures are estimated, so your budget doesn't reflect your real activity.")
                        Spacer()
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
