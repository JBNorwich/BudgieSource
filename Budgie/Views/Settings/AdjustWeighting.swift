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
import Charts

struct WeightOptions: View {
    var body: some View {
        Text("Don't weight down").tag(-2)
        Text("Forgiving").tag(-1)
        Text("Default").tag(0)
        Text("Harsh").tag(1)
        Text("Don't predict").tag(2)
        Text("Default (old)").tag(3)
    }
}

func weightForGraph(input: Int, style: Int, timeInput: Int) -> Double {
    let time = Double(timeInput)
    
    // multiplier = discount on active projection (i.e. lower fraction = user gets less credit)
    // startTime = time that weighting down starts
    // stopTime = time to stop projecting future active calories entirely
    // exponent = power to which factor is multiplied
    let (multiplier, startTime, stopTime, exponent): (Double, Double, Double, Double)
    switch style {
        case -1:    (multiplier, startTime, stopTime, exponent) = (1, 240, 1440, 5)
        case 0:     (multiplier, startTime, stopTime, exponent) = (0.5, 0, 1320, 2)
        case 1:     (multiplier, startTime, stopTime, exponent) = (0.25, 0, 1320, 1)
        default:    (multiplier, startTime, stopTime, exponent) = (1, 0, 1440, 0)
    }
    
    let weightTime = max(time,startTime)
    let weightFactor: Double = weightTime/stopTime
    let finalWeightFactor = 1 - pow(weightFactor, exponent)
    
    return max(finalWeightFactor * Double(input) * multiplier, 0)
}

struct WeightingChartPiece {
    var percent: Double
}

class WeightingChartObject {
    var forgiving: [WeightingChartPiece]
    var regular: [WeightingChartPiece]
    var harsh: [WeightingChartPiece]
    
    init() {
        forgiving = []
        regular = []
        harsh = []
        var time: Int = 0
        while time < 1440 {
            let newForgivingPiece = WeightingChartPiece(percent: weightForGraph(input: 100, style: -1, timeInput: time))
            let newRegularPiece = WeightingChartPiece(percent: weightForGraph(input: 100, style: 0, timeInput: time))
            let newHarshPiece = WeightingChartPiece(percent: weightForGraph(input: 100, style: 1, timeInput: time))
            forgiving.append(newForgivingPiece)
            regular.append(newRegularPiece)
            harsh.append(newHarshPiece)
            time += 60
        }
    }
}

let foregroundStyleDict: KeyValuePairs = (["Forgiving": Color.blue, "Default": Color.yellow, "Harsh": Color.red])

struct AdjustWeighting: View {
    @State private var refreshID = UUID()
    
    private func settingBinding<T>(_ keyPath: ReferenceWritableKeyPath<CloudSettings, T>) -> Binding<T> {
        Binding(
            get: { settingsObj[keyPath: keyPath] },
            set: { newValue in
                settingsObj[keyPath: keyPath] = newValue
                refreshID = UUID() // forces redraw on update
            }
        )
    }
    
    var body: some View {
        let object = WeightingChartObject()
        let xdata = Array(0...23)   // sample nr is computed at nr*60 minutes, i.e. hour nr
        Form {
            Section(header: Text("Style of calorie weighting"), footer: Text(.init(weightingText))) {
                Chart(0..<xdata.count, id: \.self) { nr in
                    LineMark(
                        x: .value("Time", xdata[nr]),
                        y: .value("Forgiving", object.forgiving[nr].percent),
                        series: .value("Forgiving", "A")
                    )
                    .foregroundStyle(.blue)
                    LineMark(
                        x: .value("Time", xdata[nr]),
                        y: .value("Default", object.regular[nr].percent),
                        series: .value("Default", "B")
                    )
                    .foregroundStyle(.yellow)
                    LineMark(
                        x: .value("Time", xdata[nr]),
                        y: .value("Harsh", object.harsh[nr].percent),
                        series: .value("Harsh", "C"))
                    .foregroundStyle(.red)
                }.chartXScale(domain: 0...24)
                    .chartForegroundStyleScale(foregroundStyleDict)
                    .chartLegend(.visible)
                    .chartLegend(position: .bottom, alignment: .center)
                    .padding()
                    .frame(minHeight: 200)
                
                Toggle("Weight differently each day", isOn: settingBinding(\.differentWeights))
                    .toggleStyle(SwitchToggleStyle())
                if !settingsObj.differentWeights {
                    Picker("Weighting style", selection: settingBinding(\.weightingStyle)) {
                        WeightOptions()
                    }.pickerStyle(.menu)
                } else {
                    Picker("Monday", selection: settingBinding(\.monWeight)) { WeightOptions() }.pickerStyle(.menu)
                    Picker("Tuesday", selection: settingBinding(\.tuesWeight)) { WeightOptions() }.pickerStyle(.menu)
                    Picker("Wednesday", selection: settingBinding(\.wedsWeight)) { WeightOptions() }.pickerStyle(.menu)
                    Picker("Thursday", selection: settingBinding(\.thursWeight)) { WeightOptions() }.pickerStyle(.menu)
                    Picker("Friday", selection: settingBinding(\.friWeight)) { WeightOptions() }.pickerStyle(.menu)
                    Picker("Saturday", selection: settingBinding(\.satWeight)) { WeightOptions() }.pickerStyle(.menu)
                    Picker("Sunday", selection: settingBinding(\.sunWeight)) { WeightOptions() }.pickerStyle(.menu)
                }
            }
        }.frame(maxHeight: .infinity)
        .navigationTitle("Calorie weighting options")
        .id(refreshID)
    }
}

//#Preview {
//    AdjustWeighting()
//}
