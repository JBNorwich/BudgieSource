//
//  SettingsView.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 20/08/2024.
//

import SwiftUI

struct SettingsView: View {
    @Binding var dataStore: HealthData
    @Binding var todayLump: TodayLump
    @Binding var whale: Bool
    
    @State private var showingSheet: Bool = false
    @State private var showingBMRHelper: Bool = false
    @State var manualBMR: Int = 0
    @State var manualActive: Int = 0
    @State var doubleDeficit: Double = 0
    @State var desiredSurplus: Double = 0
    @State var manualMode: Bool = false
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
    
    @FocusState private var focusResting: Bool
    @FocusState private var focusActive: Bool
    
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
                        BudgetHelperView(isPresented: $showingSheet, doubleDeficit: $doubleDeficit, settingsObj: settingsObj)
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
                    BMRHelper(isPresented: $showingBMRHelper, manualBMR: $manualBMR, manualActive: $manualActive, settingsObj: settingsObj)
                }.presentationDragIndicator(.visible)
            }
            
            Section(header: Text("Surplus mode"), footer: Text("Turn this on to aim for a caloric surplus, rather than a deficit.")) {
                Toggle("Aim to gain weight", isOn: $surplusMode)
                if surplusMode == true {
                    Text("Get them gains. 💪")
                }
            }
            
            Section(header: Text("Apple Health"), footer: Text("If Budgie Diet was granted access to your Apple Health data, turning this on will stop it from using or adding new data, but old food entries it's logged will stay. Your budgets will be based on the manual calorie burn figures set above, rather than real data.\n\nIf Budgie Diet doesn't have access to your Apple Health data, this setting won't change anything.")) {
                Toggle("Ignore Apple Health data", isOn: $manualMode)
            }
            
            if manualMode != true {
                Section(header: Text("Move goal"), footer: Text("If this is turned on, Budgie Diet will use your Apple Fitness Move goal as the starting point for your budget, rather than your average calorie burn figures."))
                {
                    Toggle("Use Move goal for budget", isOn: $useFitnessGoal)
                }
            }
                       
            if manualMode != true {
                Section(header: Text("Advanced")) {
                    NavigationLink {
                        BudgetCap(dataStore: $dataStore)
                    } label: {
                        Text("Budget capping")
                    }
                    
                    NavigationLink {
                        AdjustWeighting(dataStore: $dataStore)
                    } label: {
                        Text("Budget weighting options")
                    }
                }
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
                                .frame(maxWidth: 100,maxHeight: 100)
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
                    Text("Version 1.3.2 (250306.1)")
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
            manualMode = settingsObj.manualMode
            manualBMR = settingsObj.manualBMR
            manualActive = settingsObj.manualActive
            surplusMode = settingsObj.surplusMode
            whalesEverywhere = settingsObj.whalesEverywhere
            if surplusMode == true {
                doubleDeficit = Double(-settingsObj.desiredDeficit)
            } else {
                doubleDeficit = Double(settingsObj.desiredDeficit)
            }
            desiredSurplus = doubleDeficit
            healthLogging = settingsObj.healthLogging
            hideTodayInDetail = settingsObj.hideTodayInDetail
            useFitnessGoal = settingsObj.useFitnessGoal
            pingSettingsToWatch()
        }
    
        .onChange(of: manualMode, initial: false) {
            settingsObj.manualMode = manualMode
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of manual mode on settings page"
            dataStore.dataUpdated = true
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
    
        .onChange(of: surplusMode, initial: false) {
            if surplusMode == true
            {
                //need to save a negative number
                settingsObj.surplusMode = surplusMode
                desiredSurplus = doubleDeficit
                settingsObj.desiredDeficit = Int(-desiredSurplus)
                todayLump.desiredDeficit = Int(-desiredSurplus)
            } else {
                //need to save a positive number
                settingsObj.surplusMode = surplusMode
                doubleDeficit = desiredSurplus
                settingsObj.desiredDeficit = Int(doubleDeficit)
                todayLump.desiredDeficit = Int(doubleDeficit)
            }
            pingSettingsToWatch()
            dataStore.lastUpdateRequestSource = "Change of deficit on settings page"
            dataStore.dataUpdated = true
        }
        
        .onChange(of: useFitnessGoal, initial: false) {
            settingsObj.useFitnessGoal = useFitnessGoal
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
        settingsObj.manualMode = manualMode
        settingsObj.manualBMR = manualBMR
        settingsObj.manualActive = manualActive
        dataStore.lastUpdateRequestSource = "pingManual function on settings page"
        pingSettingsToWatch()
        dataStore.dataUpdated = true
    }
    
    func pingDeficit() {
        if surplusMode == false
        {
            settingsObj.desiredDeficit = Int(doubleDeficit)
        } else {
            settingsObj.desiredDeficit = Int(-desiredSurplus)
        }
        dataStore.lastUpdateRequestSource = "pingDeficit function on settings page"
        pingSettingsToWatch()
        dataStore.dataUpdated = true
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
        @State var data: HealthData = HealthData()

        var body: some View {
            SettingsView(dataStore: $data, todayLump: $lump, whale: $whale)
        }
    }
    
    return Preview()
}
