//
//  WeightGoalSheet.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 22/03/2026.
//

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
                        if (settingsObj.desiredDeficit > 0) {
                            if kilos! < todayLump.weightToday {
                                Text("Your current weight is \(todayLump.weightToday.formatted())kg, so you'll need to lose \(toLose.formatted())kg to get to this goal.")
                            } else {
                                Text("This goal is above your current weight. Are you sure this is right?")
                            }
                        } else {
                            //if aiming for surplus do something here
                        }
                        if daysToGo > 0 {
                            Text("Assuming you hit your target deficit every day, this will take you \(friendlyDuration).")
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
                    toLose = todayLump.weightToday - kilos!
                    daysToGo = getDaysToLose(weight: toLose, deficit: settingsObj.desiredDeficit)
                    friendlyDuration = formatDuration(days:daysToGo)
                }
            }
        }
    }
}
