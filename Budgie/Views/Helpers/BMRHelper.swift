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

func showFootFromCM(cms: Int) -> Int {
    let workingCms = Double(cms)
    let feet = workingCms * 0.0328084
    let feetShow = Int(floor(feet))

    return feetShow
}

func showInchesFromCM(cms: Int) -> Int {
    let workingCms = Double(cms)
    let feet = workingCms * 0.0328084 //5.74147
    let feetShow = floor(feet) //5
    let feetRest: Double = feet - feetShow //0.74147
    let inches = (feetRest * 12).rounded(.up) // 9
    var retInches = Int(inches)
    if retInches > 11
    {
        retInches = 11
    }
    return retInches
}

func showCMfromFootIn(feet: Int, inches: Int) -> Int
{
    let doubleFeet = Double(feet)
    let doubleInches = Double(inches)
    let feetInCm = doubleFeet * 30.48
    let inchInCm = doubleInches * 2.54
    let totalCm = feetInCm + inchInCm
    return Int(totalCm)
}

func lbToKg(lbs: Int) -> Int{
    var resultDouble: Double = Double(lbs) * lbInKg //89.89
    resultDouble = resultDouble.rounded()
    return Int(resultDouble)
}

func kgToLb(kgs: Int) -> Int {
    var resultDouble: Double = Double(kgs) / lbInKg // 198.237...
    resultDouble = resultDouble.rounded()
    return Int(resultDouble)
}

struct BMRHelper: View {
    @Binding var isPresented: Bool
    @Binding var manualBMR: Int
    @Binding var manualActive: Int

    @State var selectedSex: Int = 0
    @State var yearOfBirth: Int = 2000
    @State var heightCM: Int = 175
    @State var heightFt: Int = 5
    @State var heightIn: Int = 9
    @State var weightKg: Int = 90
    @State var weightLb: Int = 198
    @State var weightSt: Int = 14
    @State var weightStLb: Int = 2
    @State var metricImperial: Int = 0
    @State var weightUnitSelection: Int = 0
    @State var activityLevel: Double = 0.2

    private enum Field { case weightKg, weightLb, weightSt, weightStLb, heightCM }
    @FocusState private var focusedField: Field?

    /// The weight unit currently chosen in this sheet's picker.
    private var currentWeightUnit: weightUnits {
        weightUnits(rawValue: weightUnitSelection) ?? .kilograms
    }

    /// The entered weight, always resolved back to whole kilograms for storage/BMR.
    private var weightInKg: Int {
        kilograms(from: currentWeightUnit)
    }
    
    /// Resolve whichever unit's fields into whole kilograms.
    private func kilograms(from unit: weightUnits) -> Int {
        switch unit {
        case .kilograms:
            return weightKg
        case .pounds:
            return lbToKg(lbs: weightLb)
        case .stonepounds:
            return Int(StonePounds(stones: weightSt, pounds: weightStLb).kilos.rounded())
        }
    }

    /// Keep every unit's field representation in step with a known kilogram value.
    private func syncWeightFields(fromKg kg: Int) {
        weightKg = kg
        weightLb = kgToLb(kgs: kg)
        let sp = StonePounds(kilos: Double(kg))
        weightSt = sp.stones
        weightStLb = sp.pounds
    }
    
    private var birthYearRange: ClosedRange<Int> {
        let thisYear = Calendar.current.component(.year, from: Date())
        return (thisYear - 100)...(thisYear - 18)
    }

    /// A trailing-aligned whole-number field with a unit suffix — the shape repeated by every
    /// weight/height field below, differing only in which value, suffix and focus target they bind.
    @ViewBuilder
    private func numberField(_ value: Binding<Int>, suffix: String, focus: Field) -> some View {
        TextField("", value: value, format: .number)
            .multilineTextAlignment(.trailing)
            .keyboardType(.numberPad)
            .autocorrectionDisabled()
            .focused($focusedField, equals: focus)
        Text(suffix)
    }

    var body: some View {
        Form {
            Section(header: Text("About you")) {
                LabeledContent {
                    Picker("Sex", selection: $selectedSex) {
                        Text("Male").tag(1)
                        Text("Female").tag(2)
                    }
                    .pickerStyle(.segmented)
                } label: {
                    HStack {
                        Text("Sex at birth")
                        Spacer()
                    }
                }
                LabeledContent
                {
                    Picker("Year of birth", selection: $yearOfBirth) {
                        ForEach(birthYearRange.reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 125)
                } label: {
                    HStack {
                        Text("Year of birth")
                        Spacer()
                    }
                }

                // Weight units — persists app-wide and drives the field(s) below.
                Picker("Weight units", selection: $weightUnitSelection) {
                    Text("Kilograms").tag(0)
                    Text("Pounds").tag(1)
                    Text("Stone & pounds").tag(2)
                }

                // Weight — entered in the chosen weight unit.
                switch currentWeightUnit {
                case .kilograms:
                    LabeledContent {
                        HStack { numberField($weightKg, suffix: "kg", focus: .weightKg) }
                    } label: {
                        Text("Weight")
                    }
                case .pounds:
                    LabeledContent {
                        HStack { numberField($weightLb, suffix: "lbs", focus: .weightLb) }
                    } label: {
                        Text("Weight")
                    }
                case .stonepounds:
                    LabeledContent {
                        HStack {
                            numberField($weightSt, suffix: "st", focus: .weightSt)
                            numberField($weightStLb, suffix: "lb", focus: .weightStLb)
                        }
                    } label: {
                        Text("Weight")
                    }
                }

                // Height units control height entry only.
                Picker("Height units", selection: $metricImperial)
                {
                    Text("Metric").tag(0)
                    Text("Imperial").tag(1)
                }
                if metricImperial == 0 {
                    LabeledContent {
                        HStack { numberField($heightCM, suffix: "cm", focus: .heightCM) }
                    } label: {
                        Text("Height")
                    }
                } else {
                    LabeledContent {
                        HStack {
                            Picker("", selection: $heightFt) {
                                ForEach(1...8, id: \.self) { ft in
                                    Text("\(ft)ft").tag(ft)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 125)

                            Picker("", selection: $heightIn) {
                                ForEach(0...11, id: \.self) { inch in
                                    Text("\(inch)in").tag(inch)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 125)
                        }
                    } label: {
                        HStack {
                            Text("Height")
                            Spacer()
                        }
                    }
                }
            }

            Section(header: Text("Your activity")) {
                Picker("Usual activity", selection: $activityLevel) {
                    Text("None").tag(0.2)
                    Text("Light").tag(0.375)
                    Text("Moderate").tag(0.55)
                    Text("Lots").tag(0.725)
                    Text("Extremely active").tag(0.9)
                }
                Text(getActivityNarrative(activityLevel:activityLevel))
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Calculate resting and active calories") {
                    var calcCM = 0
                    if metricImperial == 1 {
                        calcCM = showCMfromFootIn(feet: heightFt, inches: heightIn)
                    } else {
                        calcCM = heightCM
                    }
                    let calcWeightKg = weightInKg
                    let age = Calendar.current.component(.year, from: Date()) - yearOfBirth
                    manualBMR = calcBMR(height: calcCM, weight: calcWeightKg, age: age, sex: selectedSex)
                    let activeCals = Double(manualBMR) * activityLevel
                    manualActive = 10 * Int(round(activeCals / 10.0))
                    settingsObj.manualActive = manualActive
                    settingsObj.manualBMR = manualBMR
                    settingsObj.height = calcCM
                    settingsObj.weight = calcWeightKg
                    settingsObj.userSex = selectedSex
                    settingsObj.birthYear = yearOfBirth
                    settingsObj.bmrMultiplier = activityLevel
                    if settingsObj.isFirstRun == true {
                        settingsObj.startWeight = Double(calcWeightKg)
                    }
                    isPresented = false
                }
            }
        }
        .onAppear {
            heightCM = settingsObj.height
            heightFt = showFootFromCM(cms: heightCM)
            heightIn = showInchesFromCM(cms: heightCM)
            weightUnitSelection = settingsObj.weightDisplayUnit
            syncWeightFields(fromKg: settingsObj.weight)
            yearOfBirth = settingsObj.birthYear
            metricImperial = settingsObj.impMetric
            selectedSex = settingsObj.userSex
            activityLevel = settingsObj.bmrMultiplier

        }

        .onChange(of: selectedSex) {
            settingsObj.userSex = selectedSex
        }

        .onChange(of: weightUnitSelection) { oldValue, newValue in
            settingsObj.weightDisplayUnit = newValue
            // Carry the entered weight across to the newly chosen unit's fields.
            let previousUnit = weightUnits(rawValue: oldValue) ?? .kilograms
            syncWeightFields(fromKg: kilograms(from: previousUnit))
        }

        .onChange(of: metricImperial) {
            settingsObj.impMetric = metricImperial
            // Height units only — keep the cm and ft/in representations in step.
            if metricImperial == 0 {
                heightCM = showCMfromFootIn(feet: heightFt, inches: heightIn)
            } else {
                heightFt = showFootFromCM(cms: heightCM)
                heightIn = showInchesFromCM(cms: heightCM)
            }
        }

        .keyboardDoneButton(clearing: $focusedField)
    }
}

#Preview {

    struct Preview: View {
        @State var bmr = 2000
        @State var manact = 500
        @State var presented = true
        var body: some View {
            BMRHelper(isPresented: $presented, manualBMR: $bmr, manualActive: $manact)
        }
    }

    return Preview()
}
