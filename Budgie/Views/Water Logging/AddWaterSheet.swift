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

struct AddWaterSheet: View {
    @Binding var isDisplayed: Bool
    
    var dateToAddOn: Date
    @State var fieldString: String = "0"
    @State var millilitres: Int?
    @State var milsWereNil: Bool = false
    @FocusState var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Amount", value: $millilitres, format: .number)
                            .font(.largeTitle)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                        Text("ml")
                            .font(.largeTitle)
                        Button("Add") {
                            guard (millilitres ?? 0) > 0 else {
                                millilitres = nil
                                isFocused = true
                                return
                            }
                            Task {
                                await dataStore.addWater(amount: millilitres!, datetime: dateToAddOn)
                            }
                            isDisplayed = false
                        }.buttonStyle(.borderedProminent)
                    }
                }
                
                Section(header: Text("Quick add")) {
                    HStack {
                        VStack {
                            Button("250ml", systemImage: "mug.fill") {
                                Task {
                                    await dataStore.addWater(amount: 250, datetime: dateToAddOn)
                                    isDisplayed = false
                                }
                            }.buttonStyle(.bordered)
                                .controlSize(.extraLarge)
                                .buttonBorderShape(.circle)
                                .labelStyle(.iconOnly)
                            Text("250ml")
                        }
                        Spacer()
                        VStack {
                            Button("500ml", systemImage: "waterbottle") {
                                Task {
                                    await dataStore.addWater(amount: 500, datetime: dateToAddOn)
                                    isDisplayed = false
                                }
                            }.buttonStyle(.bordered)
                                .controlSize(.extraLarge)
                                .buttonBorderShape(.circle)
                                .labelStyle(.iconOnly)
                            Text("500ml")
                        }
                        Spacer()
                        VStack {
                            Button("750ml", systemImage: "waterbottle.fill") {
                                Task {
                                    await dataStore.addWater(amount: 750, datetime: dateToAddOn)
                                    isDisplayed = false
                                }
                            }.buttonStyle(.bordered)
                                .controlSize(.extraLarge)
                                .buttonBorderShape(.circle)
                                .labelStyle(.iconOnly)
                            Text("750ml")
                        }
                        Spacer()
                        VStack {
                            Button("1l", systemImage: "waterbottle.fill") {
                                Task {
                                    await dataStore.addWater(amount: 1000, datetime: dateToAddOn)
                                    isDisplayed = false
                                }
                            }.buttonStyle(.bordered)
                                .controlSize(.extraLarge)
                                .buttonBorderShape(.circle)
                                .labelStyle(.iconOnly)
                            Text("1 litre")
                        }
                    }
                }
            }
            
            .navigationTitle("Add water")
        }
        
        .alert("Millilitres can't be zero.", isPresented: $milsWereNil)
        {
            Button("OK", role: .cancel) { }
        }
    }
}

#Preview {
    struct Preview: View {
        @State var presented = true
        @State var data = HealthData()
        
        var body: some View {
            AddWaterSheet(isDisplayed:$presented, dateToAddOn: Date())
        }
    }
    return Preview()
}
