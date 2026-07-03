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

struct BudgetCap: View {
    @State var capBudget: Bool = false
    @State var capBudgetCals: Int = 0
    @FocusState private var focusCap: Bool
    
    private func commitCap() {
        capBudgetCals = max(capBudgetCals, 1200)
        settingsObj.capBudgetCals = capBudgetCals
    }
       
    var body: some View {
        Form {          
            Section(header: Text("Budget cap"), footer: Text(.init(cappingText))) {
                Toggle("Cap budget", isOn: $capBudget)
                if capBudget {
                    LabeledContent("Cap") {
                        TextField("", value: $capBudgetCals, format: .number .grouping(.automatic) .precision(.integerLength(4)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .onSubmit { commitCap() }
                            .focused($focusCap)
                    }
                }
            }
        }
        .navigationTitle("Budget capping")
        
        .onAppear {
            capBudgetCals = settingsObj.capBudgetCals
            capBudget = settingsObj.capBudget
        }
        
        .onChange(of: capBudget) {
            settingsObj.capBudget = capBudget
        }
        
        // Persist the moment the field's binding commits (including when focus is lost by
        // navigating back), so an edited cap can never be silently dropped. The 1,200 floor
        // is normalised on focus loss / Done / submit via commitCap().
        .onChange(of: capBudgetCals) {
            settingsObj.capBudgetCals = max(capBudgetCals, 1200)
        }

        .onChange(of: focusCap) {
            if !focusCap { commitCap() }
        }
        
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    commitCap()
                    focusCap = false
                }
             }
        }
    }
}
