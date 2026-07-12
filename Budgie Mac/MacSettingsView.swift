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

struct MacSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var refreshID = UUID()
    @State private var surplusMode = settingsObj.surplusMode
    @State private var showingHelper = false
    @State private var showing1000Warning = false
    @State private var deficitBeforeWarning = 0

    private func bind<T>(_ kp: ReferenceWritableKeyPath<CloudSettings, T>) -> Binding<T> {
        Binding(get: { settingsObj[keyPath: kp] },
                set: { settingsObj[keyPath: kp] = $0; refreshID = UUID() })
    }
    private var deficitBinding: Binding<Double> {
        Binding(get: { Double(abs(settingsObj.desiredDeficit)) },
                set: { settingsObj.desiredDeficit = settingsObj.surplusMode ? -Int($0) : Int($0) })
    }
    private var mealTimeBinding: Binding<Date> {
        Binding(get: { minsIntoDayIntoTime(mins: settingsObj.finalMealTime) },
                set: { settingsObj.finalMealTime = timeToMinsIntoDay(time: $0) })
    }
    private var waterUnit: volumeUnits { volumeUnits(rawValue: settingsObj.waterDisplayUnit) ?? .millilitres }
    private var waterGoalBinding: Binding<Int> {
        Binding(get: { waterUnit == .millilitres ? settingsObj.waterGoal
                       : Int((Double(settingsObj.waterGoal) / waterUnit.millilitresPerUnit).rounded()) },
                // Floor at one unit so the goal can't be 0 (which makes the water gauge divide 0/0 -> NaN).
                set: { settingsObj.waterGoal = millilitres(from: Double(max($0, 1)), in: waterUnit); refreshID = UUID() })
    }
    
    private var macroEnabledBinding: Binding<Bool> {
        Binding(get: { !settingsObj.disableMacros },
                set: { settingsObj.disableMacros = !$0; refreshID = UUID() })
    }
    @ViewBuilder private func macroGramsField(_ label: String, _ kp: ReferenceWritableKeyPath<CloudSettings, Int>) -> some View {
        LabeledContent("\(label) (g)") {
            TextField("", value: bind(kp), format: .number).frame(width: 90).multilineTextAlignment(.trailing)
        }
    }
    @ViewBuilder private func macroPercentField(_ label: String, _ kp: ReferenceWritableKeyPath<CloudSettings, Int>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 2) {
                TextField("", value: bind(kp), format: .number).frame(width: 60).multilineTextAlignment(.trailing)
                Text("%").foregroundStyle(.secondary)
            }
        }
    }
    private var macroFooter: String {
        switch settingsObj.macroGoalMode {
        case 1: return "A fixed daily target in grams for each macro. Leave one at 0 to just see its total."
        case 2:
            let total = settingsObj.proteinPercent + settingsObj.carbsPercent + settingsObj.fatPercent
            return total == 100
                ? "Each macro as a share of your daily calorie budget."
                : "Each macro as a share of your daily calorie budget. These currently add up to \(total)%; they work best totalling 100%."
        default: return "Protein, carbohydrate and fat in what you log, shown above your food list. Turn off to hide them."
        }
    }

    var body: some View {
        let _ = refreshID
        Form {
            Section {
                Label("Most of these settings won't take effect until you open the Budgie Diet iPhone app to re-sync your budgets.", systemImage: "info.circle")
            }
            
            Section {
                HStack {
                    Slider(value: deficitBinding, in: 0...1000, step: 50,
                        onEditingChanged: { editing in
                            if editing { deficitBeforeWarning = settingsObj.desiredDeficit }
                            else {
                                if !settingsObj.surplusMode && settingsObj.desiredDeficit >= 1000 { showing1000Warning = true }
                                refreshID = UUID()
                            }
                        })
                    Text("\(abs(settingsObj.desiredDeficit)) kcal").monospacedDigit().frame(width: 80, alignment: .trailing)
                }.labelsHidden()
                if !surplusMode { Button("Help me choose a goal…") { showingHelper = true } }
            } header: { Text(surplusMode ? "Calorie surplus" : "Calorie deficit") }
              footer: { Text("The net \(surplusMode ? "surplus" : "deficit") you'd like Budgie Diet to help you land at.") }

            Section {
                LabeledContent("Resting calories") {
                    TextField("", value: bind(\.manualBMR), format: .number).frame(width: 90).multilineTextAlignment(.trailing)
                }
                LabeledContent("Active calories") {
                    TextField("", value: bind(\.manualActive), format: .number).frame(width: 90).multilineTextAlignment(.trailing)
                }
            } header: { Text("Estimated daily calorie burn") }
              footer: { Text("Used on your iPhone when data from Apple Health isn't available. It doesn't change the budget shown here directly.") }
            
            Section("Surplus mode") {
                Toggle("Aim to gain weight", isOn: $surplusMode)
                    .onChange(of: surplusMode) {
                        settingsObj.surplusMode = surplusMode
                        if surplusMode, settingsObj.desiredDeficit > 0 { settingsObj.desiredDeficit *= -1 }
                        if !surplusMode, settingsObj.desiredDeficit < 0 { settingsObj.desiredDeficit *= -1 }
                        refreshID = UUID()
                    }
            }

            Section("Water") {
                Picker("Show volumes in", selection: bind(\.waterDisplayUnit)) {
                    Text(volumeUnits.millilitres.pickerLabel).tag(0)
                    Text(volumeUnits.usFluidOunces.pickerLabel).tag(1)
                    Text(volumeUnits.imperialFluidOunces.pickerLabel).tag(2)
                }
                LabeledContent("Daily water goal (\(waterUnit.suffix))") {
                    TextField("", value: waterGoalBinding, format: .number).frame(width: 90).multilineTextAlignment(.trailing)
                }
                Toggle("Increase goal with activity", isOn: bind(\.waterFromActivity))
            }
            
            Section {
                Toggle("Track macros", isOn: macroEnabledBinding)
                if !settingsObj.disableMacros {
                    Picker("Daily goal", selection: bind(\.macroGoalMode)) {
                        Text("None").tag(0)
                        Text("By grams").tag(1)
                        Text("By percentage").tag(2)
                    }
                    if settingsObj.macroGoalMode == 1 {
                        macroGramsField("Protein", \.proteinGoalGrams)
                        macroGramsField("Carbs", \.carbsGoalGrams)
                        macroGramsField("Fat", \.fatGoalGrams)
                    } else if settingsObj.macroGoalMode == 2 {
                        macroPercentField("Protein", \.proteinPercent)
                        macroPercentField("Carbs", \.carbsPercent)
                        macroPercentField("Fat", \.fatPercent)
                        Button("Reset to default split") {
                            settingsObj.proteinPercent = 30
                            settingsObj.carbsPercent = 40
                            settingsObj.fatPercent = 30
                            refreshID = UUID()
                        }
                    }
                }
            } header: { Text("Macros") }
              footer: { Text(macroFooter) }

            Section() {
                DatePicker("Typical evening meal time", selection: mealTimeBinding, displayedComponents: .hourAndMinute)
                Toggle("Cap my daily budget", isOn: bind(\.capBudget))
                if settingsObj.capBudget {
                    LabeledContent("Maximum budget") {
                        TextField("", value: Binding(get: { settingsObj.capBudgetCals },
                            set: { settingsObj.capBudgetCals = max($0, 1200); refreshID = UUID() }),
                            format: .number).frame(width: 90).multilineTextAlignment(.trailing)
                    }
                }
            }   header: { Text("Advanced") }
                footer: { Text("This lets you cap your budget, so even if you exercise more than expected, your budget will not exceed this amount (i.e. Budgie Diet will not prompt you to \"eat back\" all the calories you've burned over your averages).\n\nBudgie Diet is hard-coded to not give you a budget below 1,200 calories a day for safety reasons - [read more about Budgie Diet's safety principles](https://joebaldwin.me.uk/apps/budgiediet/safety/).") }


        }
        .formStyle(.grouped)
        .frame(width: 470, height: 640)
        .sheet(isPresented: $showingHelper) {
            MacBudgetHelperView(isPresented: $showingHelper)
        }
        
        .sheet(isPresented: $showing1000Warning) {
            ThousandKcalWarningSheet(isDisplayed: $showing1000Warning,
                onConfirm: { refreshID = UUID() },
                onCancel: { settingsObj.desiredDeficit = deficitBeforeWarning; refreshID = UUID() })
                .frame(width: 420).padding()
        }
    }
}
