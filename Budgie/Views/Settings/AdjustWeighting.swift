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

let foregroundStyleDict: KeyValuePairs = (["Forgiving": Color.blue, "Default": Color.yellow, "Harsh": Color.red])

struct WeightOptions: View {
    var body: some View {
        Text("Don't weight down").tag(-2)
        Text("Forgiving").tag(-1)
        Text("Default").tag(0)
        Text("Harsh").tag(1)
        Text("Don't predict").tag(2)
    }
}

struct AdjustWeighting: View {
    @Binding var dataStore: HealthData
    @State var selectedOption: Int = 0
    @State var differentWeights: Bool = false
    @State var monWeight: Int = 0
    @State var tuesWeight: Int = 0
    @State var wedsWeight: Int = 0
    @State var thursWeight: Int = 0
    @State var friWeight: Int = 0
    @State var satWeight: Int = 0
    @State var sunWeight: Int = 0
    
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
                        
                        Toggle("Weight differently each day", isOn: $differentWeights)
                            .toggleStyle(SwitchToggleStyle())
                        if differentWeights == false {
                            Picker("Weighting style", selection: $selectedOption) {
                                WeightOptions()
                            }.pickerStyle(.menu)
                        } else {
                            Picker("Monday", selection: $monWeight) {
                                WeightOptions()
                            }.pickerStyle(.menu)
                            Picker("Tuesday", selection: $tuesWeight) {
                                WeightOptions()
                            }.pickerStyle(.menu)
                            Picker("Wednesday", selection: $wedsWeight) {
                                WeightOptions()
                            }.pickerStyle(.menu)
                            Picker("Thursday", selection: $thursWeight) {
                                WeightOptions()
                            }.pickerStyle(.menu)
                            Picker("Friday", selection: $friWeight) {
                                WeightOptions()
                            }.pickerStyle(.menu)
                            Picker("Saturday", selection: $satWeight) {
                                WeightOptions()
                            }.pickerStyle(.menu)
                            Picker("Sunday", selection: $sunWeight) {
                                WeightOptions()
                            }.pickerStyle(.menu)
                        }
                    }
                }.frame(maxHeight: .infinity)
        .navigationTitle("Active calorie weighting")
        
        .onAppear {
            selectedOption = settingsObj.weightingStyle
            differentWeights = settingsObj.differentWeights
            monWeight = settingsObj.monWeight
            tuesWeight = settingsObj.tuesWeight
            wedsWeight = settingsObj.wedsWeight
            thursWeight = settingsObj.thursWeight
            friWeight = settingsObj.friWeight
            satWeight = settingsObj.satWeight
            sunWeight = settingsObj.sunWeight
        }
        
        .onChange(of: selectedOption) {
            settingsObj.weightingStyle = selectedOption
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of weighting option"
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
        
        .onChange(of: differentWeights) {
            settingsObj.differentWeights = differentWeights
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of weighting option"
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
        
        .onChange(of: monWeight) {
            settingsObj.monWeight = monWeight
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of weighting option"
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
        
        .onChange(of: tuesWeight) {
            settingsObj.tuesWeight = tuesWeight
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of weighting option"
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
        
        .onChange(of: wedsWeight) {
            settingsObj.wedsWeight = wedsWeight
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of weighting option"
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
        
        .onChange(of: thursWeight) {
            settingsObj.thursWeight = thursWeight
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of weighting option"
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
        
        .onChange(of: friWeight) {
            settingsObj.friWeight = friWeight
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of weighting option"
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
        
        .onChange(of: satWeight) {
            settingsObj.satWeight = satWeight
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of weighting option"
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
        
        .onChange(of: sunWeight) {
            settingsObj.sunWeight = sunWeight
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of weighting option"
            dataStore.isBackgroundPing = false
            dataStore.dataUpdated = true
        }
    }
}

//#Preview {
//    AdjustWeighting()
//}
