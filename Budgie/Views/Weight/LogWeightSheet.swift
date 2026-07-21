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
    @State private var isSaving = false
    @FocusState private var focusedField: WeightEntryField?

    private var unit: weightUnits { weightUnits(rawValue: settingsObj.weightDisplayUnit) ?? .kilograms }

    private var enteredKilos: Double? {
        kilograms(kg: kilosField, lb: poundsField, st: stonesField, stLb: poundsPart, unit: unit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    WeightUnitEntryFields(unit: unit, placeholder: "Weight",
                                          kilos: $kilosField, pounds: $poundsField,
                                          stones: $stonesField, poundsPart: $poundsPart,
                                          focus: $focusedField)
                    DatePicker("Date and time", selection: $date, in: ...Date())
                }
                Section {
                    Button("Save") { save() }.buttonStyle(.borderedProminent).disabled(isSaving)
                }
            }
            .navigationTitle("Log weight")
            .keyboardDoneButton(clearing: $focusedField)
            .okAlert(alertText, isPresented: $showAlert)
        }
    }

    private func save() {
        guard !isSaving else { return }
        guard let kg = enteredKilos, kg > 0 else {
            alertText = "Weight must be above zero."
            showAlert = true
            return
        }
        isSaving = true
        Task {
            let uuid = await dataStore.saveHKSample(value: kg, unit: .gramUnit(with: .kilo), type: weightSampleType, date: date)
            if uuid == nil {
                alertText = "I couldn't save your weight. Check that Budgie Diet is allowed to write weight data in the Health app."
                showAlert = true
                isSaving = false
            } else {
                await dataStore.updateLump(todayLump: todayLump)
                isDisplayed = false
            }
        }
    }
}
