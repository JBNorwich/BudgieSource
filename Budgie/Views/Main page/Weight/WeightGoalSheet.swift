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

struct WeightGoalSheet: View {
    @EnvironmentObject var todayLump: TodayLump
    @Binding var isDisplayed: Bool
    
    @State var fieldString: String = "0"
    @State var kilos: Double?
    @State var kilosWereNil: Bool = false
    @FocusState var isFocused: Bool
    @State var toLose: Double = 0
    @State var daysToGo: Int = 0
    @State var friendlyDuration: String = ""
    @State var calsToBurn: Int = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Goal", value: $kilos, format: .number)
                            .font(.largeTitle)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                        Text("kg")
                            .font(.largeTitle)
                        Button("Add") {
                            if String(kilos ?? 0.0).isNumber {
                                kilos = nil
                                isFocused = true
                            } else {
                                if kilos! > 0 {
                                    settingsObj.weightGoal = kilos!
                                    isDisplayed = false
                                } else {
                                    kilosWereNil = true
                                    isFocused = true
                                }
                            }
                        }.buttonStyle(.borderedProminent)
                    }
                }
                Section {
                    if kilos != nil {
                        if todayLump.weightToday != 0 {
                            if (settingsObj.desiredDeficit > 0) {
                                kilos! < todayLump.weightToday
                                ? Text("Your current weight is \(todayLump.weightToday.formatted())kg, so you'll need to lose \(toLose.formatted())kg to get to this goal.")
                                : Text("This goal is above your current weight. Are you sure this is right?")
                            } else {
                                kilos! > todayLump.weightToday
                                ? Text("Your current weight is \(todayLump.weightToday.formatted())kg, so you'll need to gain \((-toLose).formatted())kg to get to this goal.")
                                : Text("This goal is below your current weight. Are you sure this is right?")
                            }
                        }
                        if daysToGo > 0 {
                            VStack {
                                if !settingsObj.surplusMode {
                                    Text("Assuming you meet your target deficit every day, this will take you \(friendlyDuration).")
                                    Divider()
                                    Label("Timescales given are estimates, and are not personalised. Your actual results will vary. This app is not medical advice.", systemImage: "info.circle")
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: false)
                                } else {
                                    Text("Assuming you meet your target surplus every day, this will take you \(friendlyDuration).")
                                    Divider()
                                    Label("Timescales given are estimates, and are not personalised. Your actual results will vary. Gaining muscle from a caloric surplus, rather than fat, requires strength training and a balanced, protein-rich diet. This app is not medical advice.", systemImage: "info.circle")
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: false)
                                }

                            }
                        }
                    }
                }
            }
            
            .navigationTitle("Set weight goal")
        }
        
        .alert("Your weight goal can't be zero.", isPresented: $kilosWereNil)
        {
            Button("OK", role: .cancel) { }
        }
        
        .onAppear {
            if settingsObj.weightGoal != 0 {
                kilos = settingsObj.weightGoal
                toLose = todayLump.weightToday - settingsObj.weightGoal
                daysToGo = getDaysToLose(weight: toLose, deficit: settingsObj.desiredDeficit)
                friendlyDuration = formatDuration(days:daysToGo)
            }
        }
        
        .onChange(of: kilos) {
            if kilos != nil {
                if kilos! > 0 {
                    // will be negative if new weight goal below current, positive if above (surplus)
                    toLose = todayLump.weightToday - kilos!
                    
                    if settingsObj.surplusMode {
                        daysToGo = getDaysToGain(weight: toLose, surplus: -settingsObj.desiredDeficit)
                    } else {
                        daysToGo = getDaysToLose(weight: toLose, deficit: settingsObj.desiredDeficit)
                    }
                    friendlyDuration = formatDuration(days:daysToGo)
                }
            }
        }
    }
}
