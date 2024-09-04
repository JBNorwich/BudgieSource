//
//  AdjustWeighting.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 31/08/2024.
//

import SwiftUI
import Charts

func weightForGraph(input: Int, style: Int, timeInput: Int) -> Double {
    var doubleInput = Double(input)
    let styleToUse = style
    let time = Double(timeInput)
    
    var startTime: Double
    var stopTime: Double
    var weightTime: Double
    var weightFactor: Double
    var finalWeightFactor: Double
    
    switch styleToUse {
        case -1: doubleInput = 1 * doubleInput
        case 0: doubleInput = 0.75 * doubleInput
        case 1: doubleInput = 0.5 * doubleInput
        default: print("Doing nothing")
    }
    
    switch styleToUse {
        case -1: startTime = 240
        case 0: startTime = 0
        case 1: startTime = 0
        default: startTime = 0
    }
    switch styleToUse {
        case -1: stopTime = 1440
        case 0: stopTime = 1320
        case 1: stopTime = 1320
        default: stopTime = 1440
    }

    if time < startTime {
        weightTime = startTime
    } else {
        weightTime = time
    }
    
    switch styleToUse {
        case 2: weightFactor = 0
        default: weightFactor = weightTime/stopTime
    }
    
    switch styleToUse {
        case -1: finalWeightFactor = 1 - pow(weightFactor, 5)
        case 0: finalWeightFactor = 1 - pow(weightFactor, 2)
        case 1: finalWeightFactor = 1 - weightFactor
        default: finalWeightFactor = 0
    }
    
    let result = finalWeightFactor * doubleInput
    
    if result > 0 {
        return result
    } else {
        return 0
    }
}

struct WeightingChartPiece {
    var time: Int
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
            let newForgivingPiece = WeightingChartPiece(time: time, percent: weightForGraph(input: 100, style: -1, timeInput: time))
            let newRegularPiece = WeightingChartPiece(time: time, percent: weightForGraph(input: 100, style: 0, timeInput: time))
            let newHarshPiece = WeightingChartPiece(time: time, percent: weightForGraph(input: 100, style: 1, timeInput: time))
            forgiving.append(newForgivingPiece)
            regular.append(newRegularPiece)
            harsh.append(newHarshPiece)
            time += 60
        }
    }
}

let weightingText = "This adjusts how predicted active calories are weighted. Most people should stick with the default, but you can change it if you feel your budgets are often too high or low.\n\nThis setting doesn't affect predicted resting calories or calories not predicted from Apple Health data, which are always predicted linearly.\n\n**Forgiving:** Budgie Diet more strongly adjusts its predictions in the late evening and continues predicting until midnight, while making no adjustments to your average. This works well if you usually exercise in the evening, but it might make your budget less accurate.\n\n**Default:** This balanced setting gradually adjusts predictions from morning to 10pm, when it stops predicting new calories, and only downweights your average by about 10% when making predictions. It’s great for most people, or if your exercise schedule varies.\n\n**Harsh:** This setting starts adjusting your predictions down right away very harshly, and continues linearly throughout the day until 10pm. This is ideal for people who either exercise in the early morning or not at all, but will significantly reduce your budget otherwise.\n\n**No predictions at all:** Budgie Diet won’t estimate active calories for you. Your budget will only include resting calories and any exercise you’ve done. It’ll be very accurate, but might feel a bit restrictive, especially in the mornings."

let foregroundStyleDict: KeyValuePairs = (["Forgiving": Color.blue, "Default": Color.yellow, "Harsh": Color.red])

struct AdjustWeighting: View {
    @Binding var dataStore: HealthData
    @State var selectedOption: Int = 0
    
    var body: some View {
        let object = WeightingChartObject()
        let xdata = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
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
        
                        Picker("Weighting style", selection: $selectedOption) {
                                        Text("Forgiving").tag(-1)
                                        Text("Default").tag(0)
                                        Text("Harsh").tag(1)
                                        Text("No predictions at all").tag(2)
                        }.pickerStyle(.inline)
                            .labelsHidden()
                    }
                }.frame(maxHeight: .infinity)
        .navigationTitle("Active calorie weighting")
        
        .onAppear {
            selectedOption = settingsObj.weightingStyle
        }
        
        .onChange(of: selectedOption) {
            settingsObj.weightingStyle = selectedOption
            dataStore.lastUpdateRequestSource = "Change of weighting option"
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
    }
}

//#Preview {
//    AdjustWeighting()
//}
