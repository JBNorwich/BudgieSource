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
    @State var millilitres: Int?
    @State var milsWereNil: Bool = false
    @FocusState var isFocused: Bool
    
    struct QuickWaterButton: View {
        let image: String
        let amount: Int
        let date: Date
        @Binding var isDisplayed: Bool
        
        var body: some View {
            VStack {
                Button("\(amount)ml", systemImage: image) {
                    Task {
                        await dataStore.addWater(amount: amount, datetime: date)
                        isDisplayed = false
                    }
                }.buttonStyle(.bordered)
                    .controlSize(.extraLarge)
                    .buttonBorderShape(.circle)
                    .labelStyle(.iconOnly)
                Text("\(amount)ml")
            }
        }
    }
    
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
                                milsWereNil = true
                                isFocused = true
                                return
                            }
                            Task {
                                await dataStore.addWater(amount: millilitres!, datetime: dateToAddOn)
                                isDisplayed = false
                            }
                        }.buttonStyle(.borderedProminent)
                    }
                }
                
                Section(header: Text("Quick add")) {
                    HStack {
                        QuickWaterButton(image: "mug.fill", amount: 250, date: dateToAddOn, isDisplayed: $isDisplayed)
                        Spacer()
                        QuickWaterButton(image: "waterbottle", amount: 500, date: dateToAddOn, isDisplayed: $isDisplayed)
                        Spacer()
                        QuickWaterButton(image: "waterbottle.fill", amount: 750, date: dateToAddOn, isDisplayed: $isDisplayed)
                        Spacer()
                        QuickWaterButton(image: "waterbottle.fill", amount: 1000, date: dateToAddOn, isDisplayed: $isDisplayed)
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
        
        var body: some View {
            AddWaterSheet(isDisplayed:$presented, dateToAddOn: Date())
        }
    }
    return Preview()
}
