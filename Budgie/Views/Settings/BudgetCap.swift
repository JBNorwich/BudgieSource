//
//  AdjustWeighting.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 31/08/2024.
//

import SwiftUI

struct BudgetCap: View {
    @State var capBudget: Bool = false
    @State var capBudgetCals: Int = 0
    @FocusState private var focusCap: Bool
       
    var body: some View {
        Form {          
            Section(header: Text("Budget cap"), footer: Text(.init(cappingText))) {
                Toggle("Cap budget", isOn: $capBudget)
                if (capBudget == true) {
                    LabeledContent() {
                        TextField(capBudgetCals.formatted(), value: $capBudgetCals, format: .number .grouping(.automatic) .precision(.integerLength(4)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .onSubmit {
                                if capBudgetCals > 1400
                                {
                                    pingCap()
                                } else {
                                    capBudgetCals = 1400
                                }
                            }
                            .focusable()
                            .focused($focusCap)
                    } label: { Text("Cap") }
                }
            }
        }
        .navigationTitle("Budget capping")
        
        .onAppear {
            capBudget = settingsObj.capBudget
            capBudgetCals = settingsObj.capBudgetCals
        }
        
        .onChange(of: capBudget) {
            settingsObj.capBudget = capBudget
            pingSettingsToWatch()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    let prevCals = capBudgetCals
                    if capBudgetCals > 999
                    {
                        pingCap()
                    } else {
                        capBudgetCals = prevCals
                    }
                    
                    if focusCap == true { focusCap.toggle() }
                }
             }
        }
    }
    
    
    
    func pingCap() {
        settingsObj.capBudgetCals = capBudgetCals
        pingSettingsToWatch()
    }
}

//#Preview {
//    AdjustWeighting()
//}
