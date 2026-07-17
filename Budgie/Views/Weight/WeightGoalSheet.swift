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

    // Input fields — only the ones relevant to the chosen unit are shown.
    @State private var kilosField: Double?
    @State private var poundsField: Double?
    @State private var stonesField: Int?
    @State private var poundsPart: Int?

    @State private var goalWasInvalid: Bool = false

    private enum Field { case kilos, pounds, stones, poundsPart }
    @FocusState private var focusedField: Field?

    @State private var toLose: Double = 0
    @State private var daysToGo: Int = 0
    @State private var friendlyDuration: String = ""
    
    /// The minimum BMI that Budgie Diet will let the user aim for.
    private let healthyBMIFloor = 18.5

    /// The unit the user has chosen for displaying/entering weights.
    private var unit: weightUnits {
        weightUnits(rawValue: settingsObj.weightDisplayUnit) ?? .kilograms
    }

    /// The goal the user has entered, converted to kilograms for storage.
    /// Returns nil when nothing meaningful has been entered.
    private var enteredKilos: Double? {
        switch unit {
        case .kilograms:
            return kilosField
        case .pounds:
            guard let pounds = poundsField else { return nil }
            return pounds * lbInKg
        case .stonepounds:
            let stones = stonesField ?? 0
            let pounds = poundsPart ?? 0
            guard stones != 0 || pounds != 0 else { return nil }
            return StonePounds(stones: stones, pounds: pounds).kilos
        }
    }
    
    /// The BMI implied by the entered goal weight and the user's stored height.
    /// Returns nil when we lack the information to compute it meaningfully.
    private var goalBMI: Double? {
        guard let goal = enteredKilos, goal > 0 else { return nil }
        let heightM = Double(settingsObj.height) / 100
        guard heightM > 0 else { return nil }
        return goal / (heightM * heightM)
    }

    /// Whether the entered goal would place the user in the underweight BMI range.
    private var goalIsUnderweight: Bool {
        guard let bmi = goalBMI else { return false }
        return bmi < healthyBMIFloor
    }
    
    /// The lowest weight in the healthy BMI range (18.5) for the user's stored height.
    /// Rounded up to the nearest 0.1 kg so the figure shown is never itself underweight.
    /// Returns nil when height is unavailable.
    private var minimumHealthyWeight: Double? {
        let heightM = Double(settingsObj.height) / 100
        guard heightM > 0 else { return nil }
        let raw = healthyBMIFloor * heightM * heightM
        return (raw * 10).rounded(.up) / 10
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch unit {
                    case .kilograms:
                        HStack {
                            TextField("Goal", value: $kilosField, format: .number)
                                .font(.largeTitle)
                                .keyboardType(.decimalPad)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .kilos)
                            Text("kg")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                    case .pounds:
                        HStack {
                            TextField("Goal", value: $poundsField, format: .number)
                                .font(.largeTitle)
                                .keyboardType(.decimalPad)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .pounds)
                            Text("lbs")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                    case .stonepounds:
                        HStack {
                            TextField("0", value: $stonesField, format: .number)
                                .font(.largeTitle)
                                .keyboardType(.numberPad)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .stones)
                            Text("st")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            TextField("0", value: $poundsPart, format: .number)
                                .font(.largeTitle)
                                .keyboardType(.numberPad)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .poundsPart)
                            Text("lb")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Add") {
                        guard let goal = enteredKilos, goal > 0 else {
                            goalWasInvalid = true
                            focusedField = firstField
                            return
                        }
                        // If the old goal was already reached, restart progress from the current weight
                        // so the new goal's gauge begins fresh rather than from the original baseline.
                        if todayLump.weightGoalMet, todayLump.weightToday != 0 {
                            settingsObj.startWeight = todayLump.weightToday
                        }
                        settingsObj.weightGoal = goal
                        isDisplayed = false
                    }.buttonStyle(.borderedProminent)
                }

                Section {
                    if goalIsUnderweight, let minWeight = minimumHealthyWeight {
                        Label("This goal weight is in the underweight range (a BMI below 18.5) for the height I have stored for you. The lowest healthy weight for your height is around \(renderWeight(kilos: minWeight)). Aiming for below a healthy weight carries real and serious health risks. Please consider discussing this goal with your doctor before continuing.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Link("Find out more", destination: URL(string: "https://www.nhs.uk/live-well/healthy-weight/managing-your-weight/advice-for-underweight-adults/")!)
                    }
                    if let goal = enteredKilos {
                        // If the user's target is 0 they've expressly said they don't want their
                        // weight to change, so a lose/gain framing isn't meaningful — say nothing.
                        if todayLump.weightToday != 0 && settingsObj.desiredDeficit != 0 {
                            if settingsObj.surplusMode {
                                goal > todayLump.weightToday
                                ? Text("Your current weight is \(renderWeight(kilos: todayLump.weightToday)), so you'll need to gain \(renderWeight(kilos: -toLose)) to get to this goal.")
                                : Text("This goal is below your current weight. Are you sure this is right?")
                            } else {
                                goal < todayLump.weightToday
                                ? Text("Your current weight is \(renderWeight(kilos: todayLump.weightToday)), so you'll need to lose \(renderWeight(kilos: toLose)) to get to this goal.")
                                : Text("This goal is above your current weight. Are you sure this is right?")
                            }
                        }
                        if daysToGo > 0 {
                            VStack {
                                if !settingsObj.surplusMode {
                                    Text("Assuming you meet your target deficit every day, this will take you \(friendlyDuration).")
                                    Divider()
                                    Label("Timescales given are estimates, and are not personalised. Your actual results will vary. This app is not medical advice.", systemImage: "info.circle")
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text("Assuming you meet your target surplus every day, this will take you \(friendlyDuration).")
                                    Divider()
                                    Label("Timescales given are estimates, and are not personalised. Your actual results will vary. Gaining muscle from a caloric surplus, rather than fat, requires strength training and a balanced, protein-rich diet. This app is not medical advice.", systemImage: "info.circle")
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }

            .navigationTitle("Set weight goal")

            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }

        .alert("Please enter a weight above zero.", isPresented: $goalWasInvalid) {
            Button("OK", role: .cancel) { }
        }

        .onAppear {
            if settingsObj.weightGoal != 0 {
                let goal = settingsObj.weightGoal
                switch unit {
                case .kilograms:
                    kilosField = goal
                case .pounds:
                    poundsField = ((goal / lbInKg) * 10).rounded() / 10
                case .stonepounds:
                    let sp = StonePounds(kilos: goal)
                    stonesField = sp.stones
                    poundsPart = sp.pounds
                }
                recalculate()
            }
        }

        .onChange(of: enteredKilos) {
            recalculate()
        }
    }

    /// The field to return focus to when the entry is rejected.
    private var firstField: Field {
        switch unit {
        case .kilograms: return .kilos
        case .pounds: return .pounds
        case .stonepounds: return .stones
        }
    }

    private func recalculate() {
        guard let goal = enteredKilos, goal > 0, todayLump.weightToday != 0 else {
            toLose = 0; daysToGo = 0; friendlyDuration = ""
            return
        }
        // Positive => need to lose; negative => need to gain.
        toLose = todayLump.weightToday - goal

        // A deficit can't reach a higher goal weight, nor a surplus a lower one — so there's no
        // timescale to quote when the goal sits the other side of where they are now.
        let movingTowardGoal = settingsObj.surplusMode ? toLose < 0 : toLose > 0
        guard movingTowardGoal else { daysToGo = 0; friendlyDuration = ""; return }

        let magnitude = abs(toLose)
        daysToGo = settingsObj.surplusMode
            ? getDaysToGain(weight: magnitude, surplus: -settingsObj.desiredDeficit)
            : getDaysToLose(weight: magnitude, deficit: settingsObj.desiredDeficit)
        friendlyDuration = formatDuration(days: daysToGo)
    }
}
