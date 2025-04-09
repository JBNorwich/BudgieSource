//
//  AddWaterSheet.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 20/03/2025.
//

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
                            if !String(millilitres ?? 0).isNumber {
                                millilitres = nil
                                isFocused = true
                            } else {
                                if millilitres ?? 0 > 0 {
                                    Task {
                                        await dataStore.addWater(amount: millilitres!, datetime: dateToAddOn)
                                        isDisplayed = false
                                    }
                                } else {
                                    milsWereNil = true
                                    isFocused = true
                                }
                            }
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
