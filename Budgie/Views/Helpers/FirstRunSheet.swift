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

struct FirstRunSheet: View {
    @EnvironmentObject var todayLump: TodayLump
    @Binding var isPresented: Bool
    
    @State var hkPermsToggle: Bool = false
    @State var showingBMRcalc: Bool = false
    @State var manualBMR: Int = 0
    @State var manualActive: Int = 0
    @State var chosenGoal: Int = 0
    @State var showingDeficitChooser: Bool = false
    @State var showingWeightGoalSheet: Bool = false
    @State var desiredSurplus: Double = 50
    @State var disclaimerOn = false
    @State var goalNotChosen = true
    
    enum Step: Int, Comparable {
        case healthKit, bmr, goal, calorieTarget, goalWeight, done
        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }
    @State private var step: Step = .healthKit
    
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
                // STEP 1
                // HealthKit authorisation
                HStack {
                    Button("Authorise Health access") {
                        hkPermsToggle.toggle()
                    }.disabled(step != .healthKit)
                    Spacer()
                    if step > .healthKit {
                        Image(systemName: "checkmark")
                    }
                    
                }
                if step == .healthKit {
                    Text("You need to do this to get the best out of Budgie Diet, as it lets me assess your recent activity to decide your budgets and bring in your food data from other apps. Please do grant permissions after hitting the button!")
                }
                
                // STEP 2
                // Manual BMR calculation
                HStack {
                    Button("Give your height and weight") {
                        showingBMRcalc.toggle()
                    }
                    .disabled(step != .bmr)
                    Spacer()
                    if (step > .bmr)
                    {
                        Image(systemName: "checkmark")
                    }
                }
                if step == .bmr {
                    Text("This helps calculate your budgets if there are gaps in your Health data, for instance if you didn't wear your Apple Watch one day.")
                }
                
                // STEP 3
                // sort out a goal
                HStack {
                    if step != .goal {
                        // grey out, show nothing
                        Button("Set your main goal")
                        { }
                            .disabled(true)
                    } else {
                        Text("Set your main goal")
                    }
                    Spacer()
                    if step > .goal
                    {
                        Image(systemName: "checkmark")
                    }
                }
                
                if step == .goal {
                    VStack {
                        Text("I want to...")
                        Picker("Goal", selection: $chosenGoal) {
                            Text("Lose weight").tag(1)
                            Text("Stay the same").tag(2)
                            Text("Gain weight").tag(3)
                        }
                        .pickerStyle(.segmented)
                        Button("Continue") {
                            switch chosenGoal {
                                case 1, 3:
                                    step = .calorieTarget
                                case 2:
                                    settingsObj.desiredDeficit = 0
                                    step = .done
                                default:
                                    break
                            }
                        }.disabled(goalNotChosen)
                    }
                }
                
                // STEP 4
                // SET CALORIE TARGET
                
                if step != .calorieTarget {
                    HStack {
                        Button("Set your calorie target")
                        { }
                            .disabled(true)
                        Spacer()
                        if step > .calorieTarget {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                if step == .calorieTarget {
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
                            step = .goalWeight
                        }
                    }
                }
                
                // STEP 5
                // Set goal weight
                
                if chosenGoal != 2 {
                    HStack {
                        Button("Set your goal weight")
                        {
                            showingWeightGoalSheet = true
                        }
                            .disabled(step != .goalWeight)
                        Spacer()
                        if step > .goalWeight {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                if step == .goalWeight {
                    Text("This is where you can set your goal weight. You can change this later.")
                }
                
                if step == .done {
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
            
            
            if step == .done {
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
                step = .bmr
            case .failure(_):
                print("Failed for some reason")
            }
        }
        
        .sheet(isPresented: $showingBMRcalc, onDismiss: { step = .goal }) {
            BMRHelper(isPresented: $showingBMRcalc, manualBMR: $manualBMR, manualActive: $manualActive)
        }.interactiveDismissDisabled(true)
    
            .sheet(isPresented: $showingDeficitChooser, onDismiss: { step = .goalWeight }) {
            BudgetHelperView(isPresented: $showingDeficitChooser, hideZero: true)
        }.interactiveDismissDisabled(true)
        
            .sheet(isPresented: $showingWeightGoalSheet, onDismiss: { step = .done }) {
            WeightGoalSheet(isDisplayed: $showingWeightGoalSheet).environmentObject(todayLump)
        }.interactiveDismissDisabled(true)
        
        .onChange(of: chosenGoal, initial: false) {
            goalNotChosen = false
        }
    }
}
