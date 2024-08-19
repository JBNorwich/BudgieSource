//
//  AdjustWeighting.swift
//  Budgie
//
//  Created by Joe Baldwin on 31/08/2024.
//

import SwiftUI
import Charts

func weightForGraph(input: Int, style: Int, timeInput: Int) -> Double {
    let styleToUse = style
    let time = Double(timeInput)
    
    var startTime: Double
    var stopTime: Double
    var weightTime: Double
    var weightFactor: Double
    var finalWeightFactor: Double
    
    switch styleToUse {
        case -1: startTime = 240
        case 0: startTime = 240
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
        case 0: finalWeightFactor = 1 - pow(weightFactor, 3)
        case 1: finalWeightFactor = 1 - weightFactor
        default: finalWeightFactor = 0
    }
    
    let result = finalWeightFactor * Double(input)
    
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

let weightingText = "This adjusts the style of weighting used for predicted active calories. Most people should stick with the default setting. However, if you find that your budgets are often too high or too low for your usual activity, you can change this.\n\nThis setting does not affect predicted resting calories or calories not predicted from Apple Health data, which are always weighted down linearly.\n\n**Forgiving:** This only really starts weighting down your predictions towards the late evening, and keeps predicting up until midnight. This is likely to suit you if you regularly do most of your day's exercise in the evening, but it will also make your budget less accurate.\n\n**Default:** This is a balanced setting that weights down predictions gradually from the morning until 10pm. It will work for most people, or people whose schedules vary.\n\n**Harsh:** This starts weighting down your predictions immediately and linearly throughout the day, with a hard stop at 10pm. This will be most likely to suit people who do most of their day's exercise early in the morning.\n\n**No projections at all:** Budgie won't project any active calories for you at all. Your budget will only take into account your resting calories for the day, plus any exercise you've actually done. Your budget will be very accurate, but probably quite restrictive."

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
                                        Text("No projections at all").tag(2)
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
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
    }
}

//#Preview {
//    AdjustWeighting()
//}
