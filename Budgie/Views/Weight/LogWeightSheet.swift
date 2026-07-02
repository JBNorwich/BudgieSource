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

struct LogWeightSheet: View {
    @EnvironmentObject var todayLump: TodayLump
    @Binding var isDisplayed: Bool

    @State private var kilosField: Double?
    @State private var poundsField: Double?
    @State private var stonesField: Int?
    @State private var poundsPart: Int?
    @State private var date: Date = Date()
    @State private var showAlert = false
    @State private var alertText = ""
    @FocusState private var focused: Bool

    private var unit: weightUnits { weightUnits(rawValue: settingsObj.weightDisplayUnit) ?? .kilograms }

    private var enteredKilos: Double? {
        switch unit {
        case .kilograms:
            return kilosField
        case .pounds:
            guard let p = poundsField else { return nil }
            return p * 0.454
        case .stonepounds:
            let s = stonesField ?? 0, p = poundsPart ?? 0
            guard s != 0 || p != 0 else { return nil }
            return StonePounds(stones: s, pounds: p).kilos
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch unit {
                    case .kilograms:
                        HStack {
                            TextField("Weight", value: $kilosField, format: .number)
                                .font(.largeTitle).keyboardType(.decimalPad).focused($focused)
                            Text("kg").font(.largeTitle).foregroundStyle(.secondary)
                        }
                    case .pounds:
                        HStack {
                            TextField("Weight", value: $poundsField, format: .number)
                                .font(.largeTitle).keyboardType(.decimalPad).focused($focused)
                            Text("lbs").font(.largeTitle).foregroundStyle(.secondary)
                        }
                    case .stonepounds:
                        HStack {
                            TextField("0", value: $stonesField, format: .number)
                                .font(.largeTitle).keyboardType(.numberPad).focused($focused)
                            Text("st").font(.largeTitle).foregroundStyle(.secondary)
                            TextField("0", value: $poundsPart, format: .number)
                                .font(.largeTitle).keyboardType(.numberPad)
                            Text("lb").font(.largeTitle).foregroundStyle(.secondary)
                        }
                    }
                    DatePicker("Date and time", selection: $date)
                }
                Section {
                    Button("Save") { save() }.buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Log weight")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
            .alert(alertText, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func save() {
        guard let kg = enteredKilos, kg > 0 else {
            alertText = "Weight can't be zero."
            showAlert = true
            return
        }
        Task {
            let uuid = await dataStore.saveHKSample(value: kg, unit: .gramUnit(with: .kilo), type: weightSampleType, date: date)
            if uuid == nil {
                alertText = "I couldn't save your weight. Check that Budgie Diet is allowed to write weight data in the Health app."
                showAlert = true
            } else {
                await dataStore.updateLump(todayLump: todayLump)
                isDisplayed = false
            }
        }
    }
}
