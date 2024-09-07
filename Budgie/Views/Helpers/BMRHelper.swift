//
//  BMRHelper.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 22/08/2024.
//

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
    var resultDouble: Double = Double(lbs) * 0.454 //89.89
    resultDouble = resultDouble.rounded()
    return Int(resultDouble)
}

func kgToLb(kgs: Int) -> Int {
    var resultDouble: Double = Double(kgs) / 0.454 // 198.237...
    resultDouble = resultDouble.rounded()
    return Int(resultDouble)
}

struct BMRHelper: View {
    @Binding var isPresented: Bool
    @Binding var manualBMR: Int
    @Binding var manualActive: Int
    
    @State var selectedSex: Int = 0
    @State var yearOfBirth: Int = 2000
    @State var age: Int = 0
    @State var years: [Int] = []
    @State var year: Int = 2024
    @State var heightCM: Int = 175
    @State var heightFt: Int = 5
    @State var heightIn: Int = 9
    @State var weightKg: Int = 90
    @State var weightLb: Int = 198
    @State var weightString: String = ""
    @State var metricImperial: Int = 0
    @State var activityLevel: Double = 0.2
    
    @FocusState var weightFocused: Bool
    @FocusState var heightFocused: Bool
    
    var settingsObj: UserSettings
    
    var body: some View {
        VStack {

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
                        Picker("Year of birth", selection: $yearOfBirth)
                        {
                            ForEach(years.indices, id: \.self) { index in
                                Text(String(years[index]))
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 125)
                        .onSubmit {
                            age = year - yearOfBirth
                        }
                    } label: {
                        HStack {
                            Text("Year of birth")
                            Spacer()
                        }
                    }
                    Picker("Units to use", selection: $metricImperial)
                    {
                        Text("Metric").tag(0)
                        Text("Imperial").tag(1)
                    }
                    if metricImperial == 0 {
                        LabeledContent {
                            HStack {
                                TextField("", value: $weightKg, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .autocorrectionDisabled()
                                    .focused($weightFocused)
                                Text("kg")
                            }
                        } label: {
                            Text("Weight")
                        }
                    } else {
                        LabeledContent {
                            HStack {
                                TextField("", value: $weightLb, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .autocorrectionDisabled()
                                    .focused($weightFocused)
                                Text("lbs")
                            }
                        } label: {
                            Text("Weight")
                        }
                    }
                    if metricImperial == 0 {
                        LabeledContent {
                            HStack {
                                TextField("", value: $heightCM, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .autocorrectionDisabled()
                                    .focused($heightFocused)
                                Text("cm")
                            }
                        } label: {
                            Text("Height")
                        }
                    } else {
                        LabeledContent {
                            HStack {
                                Picker("", selection: $heightFt)
                                {
                                    Text("1ft").tag(1)
                                    Text("2ft").tag(2)
                                    Text("3ft").tag(3)
                                    Text("4ft").tag(4)
                                    Text("5ft").tag(5)
                                    Text("6ft").tag(6)
                                    Text("7ft").tag(7)
                                    Text("8ft").tag(8)
                                }.pickerStyle(.wheel)
                                    .frame(height: 125)
                                Picker("", selection: $heightIn)
                                {
                                    Text("1in").tag(1)
                                    Text("2in").tag(2)
                                    Text("3in").tag(3)
                                    Text("4in").tag(4)
                                    Text("5in").tag(5)
                                    Text("6in").tag(6)
                                    Text("7in").tag(7)
                                    Text("8in").tag(8)
                                    Text("9in").tag(9)
                                    Text("10in").tag(10)
                                    Text("11in").tag(11)
                                }.pickerStyle(.wheel)
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
                        manualBMR = calcBMR(height: calcCM, weight: weightKg, age: age, sex: selectedSex)
                        let activeCals = Double(manualBMR) * activityLevel
                        manualActive = 10 * Int(round(activeCals / 10.0))
                        settingsObj.manualActive = manualActive
                        settingsObj.manualBMR = manualBMR
                        settingsObj.height = heightCM
                        settingsObj.weight = weightKg
                        settingsObj.userSex = selectedSex
                        settingsObj.birthYear = yearOfBirth
                        settingsObj.bmrMultiplier = activityLevel
                        isPresented = false
                    }
                }
            }
            .onAppear {
                year = Calendar.current.component(.year, from: Date())
                let firstYear = year - 100
                let finalYear = year - 18
                let diff = firstYear...finalYear
                for number in diff {
                    years.insert(number, at: 0)
                }
                
                heightCM = settingsObj.height
                heightFt = showFootFromCM(cms: heightCM)
                heightIn = showInchesFromCM(cms: heightCM)
                weightKg = settingsObj.weight
                weightLb = kgToLb(kgs: weightKg)
                yearOfBirth = settingsObj.birthYear
                metricImperial = settingsObj.impMetric
                selectedSex = settingsObj.userSex
                activityLevel = settingsObj.bmrMultiplier
                
            }.frame(minWidth:0, minHeight:0)
            
            .onChange(of: selectedSex) {
                settingsObj.userSex = selectedSex
            }
            
            .onChange(of: metricImperial) {
                settingsObj.impMetric = metricImperial
                if metricImperial == 0 {
                    // convertftintometric
                    heightCM = showCMfromFootIn(feet: heightFt, inches: heightIn)
                    weightKg = lbToKg(lbs: weightLb)
                } else {
                    heightFt = showFootFromCM(cms: heightCM)
                    heightIn = showInchesFromCM(cms: heightCM)
                    weightLb = kgToLb(kgs: weightKg)
                }
            }
            
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        if weightFocused == true { weightFocused.toggle() }
                        if heightFocused == true { heightFocused.toggle() }
                    }
                 }
            }
        }
    }
}

#Preview {
    
    struct Preview: View {
        @State var bmr = 2000
        @State var manact = 500
        @State var presented = true
        var body: some View {
            BMRHelper(isPresented: $presented, manualBMR: $bmr, manualActive: $manact, settingsObj: UserSettings())
        }
    }
    
    return Preview()
}
