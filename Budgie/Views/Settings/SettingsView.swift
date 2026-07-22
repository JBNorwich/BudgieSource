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

extension View {
    /// A "Done" button above the keyboard that clears the given focus state(s) — shared by every
    /// numeric-entry screen that otherwise repeated this toolbar verbatim.
    func keyboardDoneButton(_ focuses: FocusState<Bool>.Binding...) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focuses.forEach { $0.wrappedValue = false } }
            }
        }
    }

    /// Same as `keyboardDoneButton(_:)`, for a screen whose focus state is an optional field enum
    /// rather than a plain `Bool` — "Done" clears it to `nil`.
    func keyboardDoneButton<F>(clearing focus: FocusState<F?>.Binding) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus.wrappedValue = nil }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var todayLump: TodayLump
    
    @State private var showingSheet: Bool = false
    @State private var showingBMRHelper: Bool = false
    @State var surplusMode: Bool = false
    @State var useFitnessGoal: Bool = false
    @State var disclaimerDisplayed = false
    @State private var showing1000Warning = false
    @State private var deficitBeforeWarning = 0
    
    @FocusState private var focusResting: Bool
    @FocusState private var focusActive: Bool
    @FocusState private var focusWater: Bool
    
    @Environment(\.openURL) var openURL
    
    @State private var refreshID = UUID()
    
    private static let integerFieldFormat: IntegerFormatStyle<Int> = .number.grouping(.automatic).precision(.integerLength(1...4))

    private var deficitBinding: Binding<Double> {
        Binding(
            get: {
                settingsObj.surplusMode
                    ? Double(-settingsObj.desiredDeficit)
                    : Double(settingsObj.desiredDeficit)
            },
            set: { newValue in
                settingsObj.desiredDeficit = settingsObj.surplusMode ? Int(-newValue) : Int(newValue)
            }
        )
    }
    
    private var weightTimeBinding: Binding<Date> {
        Binding(
            get: { minsIntoDayIntoTime(mins: settingsObj.finalMealTime) },
            set: { settingsObj.finalMealTime = timeToMinsIntoDay(time: $0)})
    }
    
    private var waterGoalBinding: Binding<Int> {
        Binding(
            get: {
                let unit = volumeUnits(rawValue: settingsObj.waterDisplayUnit) ?? .millilitres
                return unit == .millilitres
                    ? settingsObj.waterGoal
                    : Int(displayValue(millilitres: settingsObj.waterGoal, in: unit).rounded())
            },
            set: { newValue in
                let unit = volumeUnits(rawValue: settingsObj.waterDisplayUnit) ?? .millilitres
                // Never allow a zero/blank goal: it makes effectiveWaterGoal 0 and the water
                // gauge divides by it (0/0 -> NaN). Floor at one unit of the chosen measure.
                let flooredDisplayValue = max(newValue, 1)
                settingsObj.waterGoal = millilitres(from: Double(flooredDisplayValue), in: unit)
                refreshID = UUID()
            }
        )
    }

    private var waterGoalLabel: String {
        let unit = volumeUnits(rawValue: settingsObj.waterDisplayUnit) ?? .millilitres
        return "Daily water goal (\(unit.suffix))"
    }

    // Pure functions of settingsObj/deficitBinding rather than state mirrors kept in sync by
    // refreshState() — SwiftUI just re-reads them whenever refreshID forces body to re-evaluate.
    private var surpDefHeader: String {
        settingsObj.surplusMode ? "Desired calorie surplus" : "Desired calorie deficit"
    }
    private var surpDefExplainer: String {
        settingsObj.surplusMode
            ? "This is the net calorie surplus you'd like Budgie Diet to help you land at."
            : "This is the net calorie deficit you'd like Budgie Diet to help you land at."
    }
    private var deficitLabel: String {
        deficitBinding.wrappedValue.formatted()
    }

    private func refreshState() {
        refreshID = UUID()
    }

    @ViewBuilder
    private func integerSettingRow(_ label: String, value: Binding<Int>, focus: FocusState<Bool>.Binding) -> some View {
        LabeledContent(label) {
            TextField("0", value: value, format: SettingsView.integerFieldFormat)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .focused(focus)
        }
    }
    
    var body: some View {
        let _ = refreshID   // observe to force redraw on setting change, without resetting scroll
        
        Form {
            Section(header: Text(surpDefHeader), footer: Text(surpDefExplainer)) {
                Slider(value: deficitBinding,
                       in: 0...1000,
                       step: 50,
                       onEditingChanged: { editing in
                    if editing {
                        // Remember where they started, so we can revert if they back out of a 1,000 deficit.
                        deficitBeforeWarning = settingsObj.desiredDeficit
                    } else {
                        // A 1,000kcal+ deficit is an extreme choice — route it through the same warning
                        // gate as the deficit chooser, rather than letting the slider set it silently.
                        if !settingsObj.surplusMode && settingsObj.desiredDeficit >= 1000 {
                            showing1000Warning = true
                        }
                        refreshState()
                    }
                },
                       minimumValueLabel: Text(""),
                       maximumValueLabel: Text(deficitLabel),
                       label: { Text("Deficit") }
                )
                .sheet(isPresented: $showing1000Warning) {
                    ThousandKcalWarningSheet(
                        isDisplayed: $showing1000Warning,
                        onConfirm: { refreshState() },
                        onCancel: {
                            settingsObj.desiredDeficit = deficitBeforeWarning
                            refreshState()
                        }
                    )
                }
                if !settingsObj.surplusMode {
                    Button("Help me choose a goal") {
                        showingSheet = true
                    }.sheet(isPresented: $showingSheet, onDismiss: { refreshState() }) {
                        BudgetHelperView(isPresented: $showingSheet)
                    }
                }
            }
            
            Section(header: Text("Estimated daily calorie burn"), footer: Text("This is used when actual calorie data from Apple Health isn't available or is incomplete."))
            {
                integerSettingRow("Resting calories", value: settingBinding(\.manualBMR, refresh: $refreshID), focus: $focusResting)
                integerSettingRow("Active calories", value: settingBinding(\.manualActive, refresh: $refreshID), focus: $focusActive)
                Button("Calculate this for me") {
                    showingBMRHelper = true
                }.sheet(isPresented: $showingBMRHelper, onDismiss: { refreshState() }) {
                    BMRHelper(isPresented: $showingBMRHelper, manualBMR: settingBinding(\.manualBMR, refresh: $refreshID), manualActive: settingBinding(\.manualActive, refresh: $refreshID))
                        .presentationDragIndicator(.visible)
                }
            }
            
            Section(header: Text("Water logging"), footer: Text("When this is on, your daily water goal increases based on your activity, to replace hydration lost when exercising."))
            {
                Picker("Show volumes in", selection: settingBinding(\.waterDisplayUnit, refresh: $refreshID)) {
                    Text(volumeUnits.millilitres.pickerLabel).tag(0)
                    Text(volumeUnits.usFluidOunces.pickerLabel).tag(1)
                    Text(volumeUnits.imperialFluidOunces.pickerLabel).tag(2)
                }
                integerSettingRow(waterGoalLabel, value: waterGoalBinding, focus: $focusWater)
                Toggle("Increase goal with activity", isOn: settingBinding(\.waterFromActivity, refresh: $refreshID))
            }
            
            Section(header: Text("Food logging"), footer: Text("Disabling OpenFoodFacts search stops Budgie Diet from searching it for nutritional information completely. You can still add and save foods manually.")) {
                NavigationLink("Macro tracking and goals") { MacroSettingsView().environmentObject(todayLump) }
                NavigationLink("Budget allocation") { AllocateBudgetView() }
                NavigationLink("Manage meals") { ManageMealsView() }
                Toggle("Disable OpenFoodFacts search", isOn: settingBinding(\.offSearchDisabled, refresh: $refreshID))
            }
            
            Section(header: Text("Weight tracking"), footer: Text("If you'd prefer to not see information about your weight, you can hide it here - you can turn it back on any time. This won't erase any data you've already logged.")) {
                Picker("Show weights in", selection: settingBinding(\.weightDisplayUnit, refresh: $refreshID)) {
                    Text("Kilograms").tag(0)
                    Text("Pounds").tag(1)
                    Text("Stones & pounds").tag(2)
                }
                Toggle("Hide weight tracking features", isOn: settingBinding(\.disableWeightFeatures, refresh: $refreshID))
            }
            
            Section(header: Text("Surplus mode"), footer: Text("Turn this on to aim for a caloric surplus, rather than a deficit.")) {
                Toggle("Aim to gain weight", isOn: $surplusMode)
            }
            
            Section(header: Text("Move goal"), footer: Text("If this is turned on, Budgie Diet will use your Apple Fitness Move goal as the starting point for your budget, rather than your average calorie burn figures."))
            {
                Toggle("Use Move goal for budget", isOn: $useFitnessGoal)
            }
            
            Section(header: Text("Advanced"), footer: Text(mealTimeText)) {
                NavigationLink("Backup and restore") { DataManagementView().environmentObject(todayLump) }
                NavigationLink("Budget capping") { BudgetCap() }
                NavigationLink("Budget weighting options") { AdjustWeighting() }
                DatePicker("Typical evening meal time", selection: weightTimeBinding, displayedComponents: .hourAndMinute)
            }
            
            Section(header: Text("Other settings")) {
                Toggle("Hide \"Today in detail\"", isOn: settingBinding(\.hideTodayInDetail, refresh: $refreshID))
                Toggle("Put whales in various places", isOn: settingBinding(\.whalesEverywhere, refresh: $refreshID))
                
            }
            
            Section(header: Text("About")) {
                VStack {
                    HStack {
                        Spacer()
                        HStack{
                            Image(.icon)
                                .resizable()
                                .frame(width: 100,height: 100)
                            VStack {
                                Text("Budgie Diet")
                                    .font(.title)
                                    .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                                Text("The calorie budget app")
                                    .font(.headline)
                            }
                            .padding()
                        }
                        Spacer()
                    }
                    Text(versionString)
                    Text(copyrightString)
                }
            }
            
            NavigationLink("Licences") { LicencesScreen() }
            NavigationLink("Tip me a protein bar!") { Donate() }
            NavigationLink("Health disclaimer") { Disclaimer(displayed: $disclaimerDisplayed) }
            Button("Send feedback/bug reports") {
                openURL(URL(string: "mailto:budgieapp@icloud.com")!)
            }
            Button("Privacy policy") {
                openURL(URL(string: "https://joebaldwin.me.uk/apps/budgiediet/privacy/")!)
            }
            Button("Frequently asked questions") {
                openURL(URL(string: "https://joebaldwin.me.uk/apps/budgiediet/faq/")!)
            }
        }

        .onAppear() {
            surplusMode = settingsObj.surplusMode
            useFitnessGoal = settingsObj.useFitnessGoal
            refreshState()
        }
        
        // Need to do this to ensure that the deficit updates properly to a surplus and vice versa and to force a UI redraw
        .onChange(of: surplusMode, initial: false)
        {
            if surplusMode {
                settingsObj.surplusMode = true
                if settingsObj.desiredDeficit > 0 {
                    settingsObj.desiredDeficit = -settingsObj.desiredDeficit
                }
            } else {
                settingsObj.surplusMode = false
                if settingsObj.desiredDeficit < 0 {
                    settingsObj.desiredDeficit = -settingsObj.desiredDeficit
                }
            }
            refreshState()
        }
        
        // Need to do this as otherwise there's no way to trigger the HealthKit permissions popup
        .onChange(of: useFitnessGoal, initial: false)
        {
            settingsObj.useFitnessGoal = useFitnessGoal
        }
        
        .navigationTitle("Settings")
        .navigationBarBackButtonHidden(false)
        .keyboardDoneButton($focusResting, $focusActive, $focusWater)
        .healthDataAccessRequest(store: healthStore, shareTypes: [], readTypes: fitnessGoalSet, trigger: useFitnessGoal) { result in
            switch result {
            case .success(_):
                print("Success!")
            case .failure(_):
                print("Failed for some reason")
            }
        }
    }
}

#Preview {
    struct Preview: View {
        @State var lump: TodayLump = TodayLump()

        var body: some View {
            SettingsView().environmentObject(lump)
        }
    }
    
    return Preview()
}
