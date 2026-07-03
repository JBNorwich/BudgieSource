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

struct SettingsView: View {
    @EnvironmentObject var todayLump: TodayLump
    
    @State private var showingSheet: Bool = false
    @State private var showingBMRHelper: Bool = false
    @State var surplusMode: Bool = false
    @State var useFitnessGoal: Bool = false
    @State private var isPresented = false
    @State var disclaimerDisplayed = false
    @State var deficitLabel: String = "0"
    @State var surpDefHeader: String = "Header goes here"
    @State var surpDefExplainer: String = "Explainer goes here"
    
    @FocusState private var focusResting: Bool
    @FocusState private var focusActive: Bool
    @FocusState private var focusWater: Bool
    
    @Environment(\.openURL) var openURL
    
    @State private var refreshID = UUID()
    
    private static let integerFieldFormat: IntegerFormatStyle<Int> = .number.grouping(.automatic).precision(.integerLength(1...4))
    
    private func settingBinding<T>(_ keyPath: ReferenceWritableKeyPath<CloudSettings, T>) -> Binding<T> {
        Binding(
            get: { settingsObj[keyPath: keyPath] },
            set: { newValue in
                settingsObj[keyPath: keyPath] = newValue
                refreshID = UUID() // forces redraw on update
            }
        )
    }
    
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
                    : Int((Double(settingsObj.waterGoal) / unit.millilitresPerUnit).rounded())
            },
            set: { newValue in
                let unit = volumeUnits(rawValue: settingsObj.waterDisplayUnit) ?? .millilitres
                settingsObj.waterGoal = millilitres(from: Double(newValue), in: unit)
                refreshID = UUID()
            }
        )
    }

    private var waterGoalLabel: String {
        let unit = volumeUnits(rawValue: settingsObj.waterDisplayUnit) ?? .millilitres
        return "Daily water goal (\(unit.suffix))"
    }
    
    private func refreshState() {
        if settingsObj.surplusMode {
            surpDefHeader = "Desired calorie surplus"
            surpDefExplainer = "This is the net calorie surplus you'd like Budgie Diet to help you land at."
        } else {
            surpDefHeader = "Desired calorie deficit"
            surpDefExplainer = "This is the net calorie deficit you'd like Budgie Diet to help you land at."
        }
        deficitLabel = deficitBinding.wrappedValue.formatted()
        refreshID = UUID()
    }
    
    var body: some View {
        Form {
            Section(header: Text(surpDefHeader), footer: Text(surpDefExplainer)) {
                Slider(value: deficitBinding,
                       in: 0...1000,
                       step: 50,
                       onEditingChanged: { _ in refreshState() },
                       minimumValueLabel: Text(""),
                       maximumValueLabel: Text(deficitLabel),
                       label: { Text("Deficit") }
                )
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
                LabeledContent {
                    TextField(settingsObj.manualBMR.formatted(), value: settingBinding(\.manualBMR), format: SettingsView.integerFieldFormat)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .focused($focusResting)
                } label: { Text("Resting calories") }
                
                LabeledContent {
                    TextField(settingsObj.manualActive.formatted(), value: settingBinding(\.manualActive), format: SettingsView.integerFieldFormat)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .focused($focusActive)
                } label: {
                    Text("Active calories")
                }
                Button("Calculate this for me") {
                    showingBMRHelper = true
                }.sheet(isPresented: $showingBMRHelper, onDismiss: { refreshState() }) {
                    BMRHelper(isPresented: $showingBMRHelper, manualBMR: settingBinding(\.manualBMR), manualActive: settingBinding(\.manualActive))
                        .presentationDragIndicator(.visible)
                }
            }
            
            Section(header: Text("Water logging"), footer: Text("When this is on, your daily water goal increases based on your activity, to replace hydration lost when exercising."))
            {
                Picker("Show volumes in", selection: settingBinding(\.waterDisplayUnit)) {
                    Text(volumeUnits.millilitres.pickerLabel).tag(0)
                    Text(volumeUnits.usFluidOunces.pickerLabel).tag(1)
                    Text(volumeUnits.imperialFluidOunces.pickerLabel).tag(2)
                }
                LabeledContent {
                    TextField(waterGoalBinding.wrappedValue.formatted(), value: waterGoalBinding, format: SettingsView.integerFieldFormat)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .focused($focusWater)
                } label: { Text(waterGoalLabel) }
                Toggle("Increase goal with activity", isOn: settingBinding(\.waterFromActivity))
            }
            
            Section(header: Text("Food logging")) {
                NavigationLink {
                    AllocateBudgetView()
                } label: {
                    Text("Budget allocation")
                }
                NavigationLink {
                    ManageMealsView()
                } label: {
                    Text("Manage meals")
                }
                
            }
            
            Section(header: Text("Weight units")) {
                Picker("Show weights in", selection: settingBinding(\.weightDisplayUnit)) {
                    Text("Kilograms").tag(0)
                    Text("Pounds").tag(1)
                    Text("Stones & pounds").tag(2)
                }
            }
            
            Section(header: Text("Surplus mode"), footer: Text("Turn this on to aim for a caloric surplus, rather than a deficit.")) {
                Toggle("Aim to gain weight", isOn: $surplusMode)
                if settingsObj.surplusMode {
                    Text("Get them gains. 💪")
                }
            }
            
            Section(header: Text("Move goal"), footer: Text("If this is turned on, Budgie Diet will use your Apple Fitness Move goal as the starting point for your budget, rather than your average calorie burn figures."))
            {
                Toggle("Use Move goal for budget", isOn: $useFitnessGoal)
            }

            Section(header: Text("Advanced"), footer: Text(mealTimeText)) {
                NavigationLink {
                    BudgetCap()
                } label: {
                    Text("Budget capping")
                }
                
                NavigationLink {
                    AdjustWeighting()
                } label: {
                    Text("Budget weighting options")
                }
                
                DatePicker("Typical evening meal time", selection: weightTimeBinding, displayedComponents: .hourAndMinute)
            }
            
            Section(header: Text("Other settings")) {
                Toggle("Hide \"Today in detail\"", isOn: settingBinding(\.hideTodayInDetail))
                Toggle("Put whales in various places", isOn: settingBinding(\.whalesEverywhere))
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

            NavigationLink {
                Donate()
            } label: {
                Text("Tip me a protein bar!")
            }
            NavigationLink {
                Disclaimer(displayed: $disclaimerDisplayed)
            } label: {
                Text("Health disclaimer")
            }
            Button("Send feedback/bug reports") {
                openURL(URL(string: "mailto:budgieapp@icloud.com")!)
            }
            Button("Privacy policy") {
                openURL(URL(string: "https://joebaldwin.me.uk/apps/budgiediet/privacy/")!)
            }
            Button("Frequently asked questions") {
                openURL(URL(string: "https://joebaldwin.me.uk/apps/budgiediet/faq/")!)
            }
        }.id(refreshID)
        

    
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
    
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusResting = false
                    focusActive = false
                    focusWater = false
                }
             }
        }
        
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
