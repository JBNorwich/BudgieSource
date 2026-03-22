//
//  FirstRunSheet.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 23/08/2024.
//

import SwiftUI

struct FirstRunSheet: View {
    @EnvironmentObject var todayLump: TodayLump
    @Binding var isPresented: Bool
    
    @State var hkBitDone: Bool = false
    @State var hkPermsToggle: Bool = false
    @State var showingBMRcalc: Bool = false
    @State var disableBMR: Bool = true
    @State var BMRdone: Bool = false
    @State var manualBMR: Int = 0
    @State var manualActive: Int = 0
    @State var goalDisabled = true
    @State var goalDone = false
    @State var chosenGoal: Int = 0
    @State var showingDeficitChooser: Bool = false
    @State var doubleDeficit: Double = 0
    @State var desiredSurplus: Double = 50
    @State var deficitDone = false
    @State var goalWeightDone = false
    @State var allComplete = false
    @State var stage = 0
    @State var disclaimerOn = false
    @State var goalNotChosen = true
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Let's get you set up!\n\nBudgie Diet doesn't send your information anywhere, has no ads and doesn't track you.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Link(destination: URL(string:"https://github.com/JBNorwich/Budgie/wiki/Privacy-policy")!) {
                    Text("Privacy policy")
                }
                
                    .navigationTitle("Welcome to Budgie Diet!")
                    .navigationBarTitleDisplayMode(.inline)
            }
            Form {
                // healthkit auth
                HStack {
                    Button("Authorise Health access") {
                        hkPermsToggle.toggle()
                    }.disabled(hkBitDone)
                    Spacer()
                    if hkBitDone == true {
                        Image(systemName: "checkmark")
                    }
                    
                }
                
                if hkBitDone != true {
                    Text("You need to do this to get the best out of Budgie Diet, as it lets me assess your recent activity to decide your budgets and bring in your food data from other apps. Please do grant permissions after hitting the button!")
                }
                
                // fallback/BMR data request
                HStack {
                    Button("Give your height and weight") {
                        showingBMRcalc.toggle()
                    }
                    .disabled(disableBMR)
                    Spacer()
                    if (BMRdone == true)
                    {
                        Image(systemName: "checkmark")
                    }
                }
                if BMRdone != true && hkBitDone == true {
                    Text("This helps calculate your budgets if there are gaps in your Health data, for instance if you didn't wear your Apple Watch one day.")
                }
                
                // sort out a goal
                HStack {
                    
                    if hkBitDone != true || BMRdone != true || goalDone == true {
                        // grey out, show nothing
                        Button("Set your main goal")
                        { }
                            .disabled(true)
                    } else {
                        Text("Set your main goal")
                    }
                    Spacer()
                    if (goalDone == true)
                    {
                        Image(systemName: "checkmark")
                    }
                }
                if (goalDone != true && hkBitDone == true && BMRdone == true) {
                    VStack {
                        Text("I want to...")
                        Picker("Goal", selection: $chosenGoal) {
                            Text("Lose weight").tag(1)
                            Text("Stay the same").tag(2)
                            Text("Gain weight").tag(3)
                        }
                        .pickerStyle(.segmented)
                        Button("Continue") {
                            goalDone = true
                        }.disabled(goalNotChosen)
                    }
                }
                
                if (goalDone == true && hkBitDone == true && BMRdone == true && goalWeightDone == true) || chosenGoal != 1 {
                    HStack {
                        Button("Set your goal weight")
                        { }
                            .disabled(true)
                        Spacer()
                        if deficitDone == true {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                if (goalDone == true && goalWeightDone != true) {
                    
                }
                
                if (goalDone != true || hkBitDone != true || BMRdone != true) || (deficitDone == true) {
                    HStack {
                        Button("Set your calorie target")
                        { }
                            .disabled(true)
                        Spacer()
                        if deficitDone == true {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                if goalDone == true && deficitDone != true {
                    //deficit
                    if chosenGoal == 1 {
                        Button("Set your calorie target")
                        {
                            showingDeficitChooser = true
                        }
                        Text("This will help you calculate your calorie deficit each day, which will set your budget. You can change this later.")
                    }
                    if chosenGoal == 3 {
                        Text("Set your calorie target")
                        Text("Use the slider below to set your target caloric surplus.")
                        Slider(value: $desiredSurplus,
                               in: 50...1000,
                               step: 50,
                               minimumValueLabel: Text(""),
                               maximumValueLabel: Text(String(Int(desiredSurplus).formatted())),
                               label: {
                            Text("Surplus")
                        })
                        Button("Save") {
                            settingsObj.surplusMode = true
                            settingsObj.desiredDeficit = Int(-desiredSurplus)
                            deficitDone = true
                            allComplete = true
                        }
                    }
                }
                
                if allComplete == true {
                    Section {
                        Text("You're all done! If you want to tweak anything, head to the Settings page by tapping the gear icon in the top left of the budget screen.")
                            .padding()
                            .multilineTextAlignment(.center)
                        Text(.init(healthDisclaimer))
                            .multilineTextAlignment(.center)
                            .font(.callout)
                        NavigationLink {
                            Disclaimer(displayed: $disclaimerOn)
                        } label: {
                            Text("Read full health disclaimer")
                        }
                    }
                }
            }
            
            
            if allComplete == true {
                Button("Start using Budgie Diet") {
                    isPresented = false
                    settingsObj.isFirstRun = false
                    Task {
                        await dataStore.updateLump(todayLump: todayLump)
                    }
                }.buttonStyle(.bordered)
                    .padding()
            }
        }
        
        .healthDataAccessRequest(store: healthStore, shareTypes: writeTypes, readTypes: readTypes, trigger: hkPermsToggle) { result in
            switch result {
            case .success(_):
                hkBitDone = true
                disableBMR = false
            case .failure(_):
                print("Failed for some reason")
            }
        }
        
        .sheet(isPresented: $showingBMRcalc) {
            BMRHelper(isPresented: $showingBMRcalc, manualBMR: $manualBMR, manualActive: $manualActive)
        }.interactiveDismissDisabled(true)
        
            .onChange(of: showingBMRcalc) {
                if showingBMRcalc == false {
                    if settingsObj.manualActive != 0 && settingsObj.manualBMR != 0 {
                        BMRdone = true
                        disableBMR = true
                    }
                }
            }
        
            .sheet(isPresented: $showingDeficitChooser) {
                BudgetHelperView(isPresented: $showingDeficitChooser, doubleDeficit: $doubleDeficit, hideZero: true)
            }.interactiveDismissDisabled(true)
        
            .onChange(of: showingDeficitChooser) {
                if showingDeficitChooser == false {
                    if settingsObj.desiredDeficit != 0 {
                        deficitDone = true
                        allComplete = true
                    }
                }
            }
        
        .onChange(of: goalDone)
        {
            if chosenGoal == 2
            {
                settingsObj.desiredDeficit = 0
                deficitDone = true
                allComplete = true
            }
        }
        
        .onChange(of: chosenGoal, initial: false) {
            goalNotChosen = false
        }
    }
}

//#Preview {
//    struct Preview: View {
//        @State var bmr = 2000
//        @State var manact = 500
//        @State var ispresent = true
//        @State var data = HealthData()
//        
//        var body: some View {
//            FirstRunSheet(isPresented: $ispresent, dataStore: $data, manualBMR:bmr, manualActive: manact)
//        }
//    }
//    
//    return Preview()
//    
//    
//}
