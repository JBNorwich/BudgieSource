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
    @Binding var whale: Bool
    
    @State private var showingSheet: Bool = false
    @State private var showingBMRHelper: Bool = false
    @State var manualBMR: Int = 0
    @State var manualActive: Int = 0
    @State var doubleDeficit: Double = 0
    @State var desiredSurplus: Double = 0
    @State var surplusMode: Bool = false
    @State var whalesEverywhere: Bool = false
    @State var circleColour: Color = .blue
    @State private var isPresented = false
    @State var calsSheetSize = PresentationDetent.medium
    @State var donateOpened = false
    @State var debugOpened = false
    @State var healthLogging = true
    @State var disclaimerDisplayed = false
    @State var hideTodayInDetail = false
    @State var useFitnessGoal = false
    @State private var weightTime = Date()
    @State var waterGoal: Int = 0
    
    @FocusState private var focusResting: Bool
    @FocusState private var focusActive: Bool
    @FocusState private var focusWater: Bool
    
    @Environment(\.openURL) var openURL
    
    var body: some View {
        Form {
            if surplusMode == false {
                Section(header: Text("Desired calorie deficit"), footer: Text("This is the net calorie deficit you'd like Budgie Diet to help you land at.")) {
                    Slider(value: $doubleDeficit,
                           in: 0...1000,
                           step: 50,
                           onEditingChanged: { _ in pingDeficit() },
                           minimumValueLabel: Text(""),
                           maximumValueLabel: Text(String(Int(doubleDeficit).formatted())),
                           label: { Text("Deficit") }
                    )
                    Button("Help me choose a goal") {
                        showingSheet = true
                    }.sheet(isPresented: $showingSheet, onDismiss: {doubleDeficit = Double(settingsObj.desiredDeficit); pingDeficit()}) {
                        BudgetHelperView(isPresented: $showingSheet, doubleDeficit: $doubleDeficit)
                    }
                }
            } else {
                Section(header: Text("Desired calorie surplus"), footer: Text("This is the net calorie surplus you'd like Budgie Diet to help you land at.")) {
                    Slider(value: $desiredSurplus,
                           in: 0...1000,
                           step: 50,
                           onEditingChanged: { _ in pingDeficit() },
                           minimumValueLabel: Text(""),
                           maximumValueLabel: Text(String(Int(desiredSurplus).formatted())),
                           label: { Text("Surplus") }
                    )
                }
            }
            
            Section(header: Text("Estimated daily calorie burn"), footer: Text("This is used when actual calorie data from Apple Health isn't available or is incomplete."))
            {
                LabeledContent {
                    TextField(manualBMR.formatted(), value: $manualBMR, format: .number .grouping(.automatic) .precision(.integerLength(1...4)))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .onSubmit {
                            let prevManual = manualBMR
                            if manualBMR < 8000
                            {
                                pingManual()
                            } else {
                                manualBMR = prevManual
                            }
                        }
                        .focusable()
                        .focused($focusResting)
                } label: { Text("Resting calories") }
                
                LabeledContent {
                    TextField(manualActive.formatted(), value: $manualActive, format: .number .grouping(.automatic) .precision(.integerLength(1...4)))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .onSubmit {
                            let prevManual = manualActive
                            if manualActive < 4000
                            {
                                pingManual()
                            } else {
                                manualActive = prevManual
                            }
                        }
                        .focusable()
                        .focused($focusActive)
                } label: {
                    Text("Active calories")
                }
                Button("Calculate this for me") {
                    showingBMRHelper = true
                }.sheet(isPresented: $showingBMRHelper, onDismiss: { pingManual() }) {
                    BMRHelper(isPresented: $showingBMRHelper, manualBMR: $manualBMR, manualActive: $manualActive)
                }.presentationDragIndicator(.visible)
            }
            
            Section(header: Text("Water goal"))
            {
                LabeledContent {
                    TextField(waterGoal.formatted(), value: $waterGoal, format: .number .grouping(.automatic) .precision(.integerLength(1...4)))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .focusable()
                        .focused($focusWater)
                } label: { Text("Daily water goal (ml)") }
            }
            
            Section(header: Text("Surplus mode"), footer: Text("Turn this on to aim for a caloric surplus, rather than a deficit.")) {
                Toggle("Aim to gain weight", isOn: $surplusMode)
                if surplusMode == true {
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
                
                DatePicker("Typical evening meal time", selection: $weightTime, displayedComponents: .hourAndMinute)
            }
            
            Section(header: Text("Other settings")) {
                Toggle("Hide \"Today in detail\"", isOn: $hideTodayInDetail)
                Toggle("Put whales in various places", isOn: $whalesEverywhere)
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
                    Text("Copyright 2024-5 Joe Baldwin")
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
        }
        

    
        .onAppear() {
            manualBMR = settingsObj.manualBMR
            manualActive = settingsObj.manualActive
            surplusMode = settingsObj.surplusMode
            whalesEverywhere = settingsObj.whalesEverywhere
            weightTime = minsIntoDayIntoTime(mins: settingsObj.finalMealTime)
            if surplusMode == true {
                doubleDeficit = Double(-settingsObj.desiredDeficit)
            } else {
                doubleDeficit = Double(settingsObj.desiredDeficit)
            }
            desiredSurplus = doubleDeficit
            healthLogging = settingsObj.healthLogging
            hideTodayInDetail = settingsObj.hideTodayInDetail
            useFitnessGoal = settingsObj.useFitnessGoal
            waterGoal = settingsObj.waterGoal
            pingSettingsToWatch()
        }
    
        .onChange(of: healthLogging, initial: false) {
            settingsObj.healthLogging = healthLogging
        }
        
        .onChange(of: hideTodayInDetail, initial: false) {
            settingsObj.hideTodayInDetail = hideTodayInDetail
        }
    
        .onChange(of: whalesEverywhere, initial: false) {
            settingsObj.whalesEverywhere = whalesEverywhere
            whale = whalesEverywhere
        }
        
        .onChange(of: waterGoal, initial: false) {
            settingsObj.waterGoal = waterGoal
        }
    
        .onChange(of: surplusMode, initial: false) {
            if surplusMode == true
            {
                //need to save a negative number
                settingsObj.surplusMode = surplusMode
                desiredSurplus = doubleDeficit
                settingsObj.desiredDeficit = Int(-desiredSurplus)
            } else {
                //need to save a positive number
                settingsObj.surplusMode = surplusMode
                doubleDeficit = desiredSurplus
                settingsObj.desiredDeficit = Int(doubleDeficit)
            }
            pingSettingsToWatch()
        }
        
        .onChange(of: useFitnessGoal, initial: false) {
            settingsObj.useFitnessGoal = useFitnessGoal
        }
        
        .onChange(of: weightTime) {
            settingsObj.finalMealTime = timeToMinsIntoDay(time: weightTime)
            pingSettingsToWatch()
        }
        
        .navigationTitle("Settings")
        .navigationBarBackButtonHidden(false)
    
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    let prevActive = manualActive
                    if manualBMR < 8000
                    {
                        pingManual()
                    } else {
                        manualBMR = prevActive
                    }
                    let prevBMR = manualBMR
                    if manualBMR < 8000
                    {
                        pingManual()
                    } else {
                        manualBMR = prevBMR
                    }
                    
                    if focusResting == true { focusResting.toggle() }
                    if focusActive == true { focusResting.toggle() }
                    if focusWater == true { focusWater.toggle() }
                }
             }
        }
    
        .navigationDestination(isPresented: $donateOpened) {
            Donate()
        }
        .navigationDestination(isPresented: $debugOpened) {
            Tests()
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
    
    func pingManual() {
        settingsObj.manualBMR = manualBMR
        settingsObj.manualActive = manualActive
        pingSettingsToWatch()
    }
    
    func pingDeficit() {
        if surplusMode == false
        {
            settingsObj.desiredDeficit = Int(doubleDeficit)
        } else {
            settingsObj.desiredDeficit = Int(-desiredSurplus)
        }
        pingSettingsToWatch()
    }
}

func pingSettingsToWatch() {
    let dict = settingsObj.dumpToDict()
    Connectivity.shared.send(settings: dict)
}

#Preview {
    struct Preview: View {
        @State var whale: Bool = false
        @State var lump: TodayLump = TodayLump()

        var body: some View {
            SettingsView(whale: $whale).environmentObject(lump)
        }
    }
    
    return Preview()
}
