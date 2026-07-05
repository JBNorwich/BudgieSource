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

struct WaterView: View {
    @EnvironmentObject var todayLump: TodayLump
    
    let gradient = Gradient(colors: [.white, .blue])
    
    var body: some View {
        VStack {
            Spacer()
            Gauge(value: todayLump.waterGoalDone, in: 0...1) {
            } currentValueLabel: {
                Text(renderVolume(millilitres: todayLump.waterToday))
            } minimumValueLabel: {
                Text("")
            } maximumValueLabel: {
                Text("")
            }.gaugeStyle(.accessoryCircular)
                .tint(gradient)
                .scaleEffect(1.5)
                .padding(.top, 10)
                .animation(.easeInOut, value: todayLump.waterGoalDone)
            Spacer()
            if todayLump.waterGoalRem != 0 {
                Text("\(renderVolume(millilitres: todayLump.waterGoalRem)) to go")
                    .font(.caption2)
                    .fixedSize()
            } else {
                Text("Goal met!")
                    .font(.caption2)
                    .fixedSize()
            }
            if todayLump.effectiveWaterGoal != settingsObj.waterGoal {
                Text("Goal: \(renderVolume(millilitres: settingsObj.waterGoal)) + \(Image(systemName: "flame")) \(renderVolume(millilitres: todayLump.effectiveWaterGoal - settingsObj.waterGoal))")
                    .font(.caption2)
                    .fixedSize()
                    .foregroundStyle(.secondary)
            } else {
                Text("Goal: \(renderVolume(millilitres: settingsObj.waterGoal))")
                    .font(.caption2)
                    .fixedSize()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
