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

import Foundation
import SwiftUI

func getActivityNarrative(activityLevel: Double) -> String {
    switch activityLevel {
        
    case 0.375: return "You exercise a couple of days a week, or very lightly."
    case 0.55: return "You exercise 3-5 days a week."
    case 0.725: return "You are very active, and exercise 6-7 days a week."
    case 0.9: return "You have a very active and physical job, and burn a lot of calories every day."
    default: return "You do little to no exercise."
    }
}

func calcBMR(height: Int, weight: Int, age: Int, sex: Int)-> Int {
    var calculated = Double()
    let doubleWeight = Double(weight)
    let doubleHeight = Double(height)
    let doubleAge = Double(age)
    
    if sex == 1 {
        //male
        calculated = 88.362 + (13.397 * doubleWeight) + (4.799 * doubleHeight) - (5.677 * doubleAge)
    } else {
        //female or nothing specified - use sensible default
        calculated = 447.593 + (9.247 * doubleWeight) + (3.098 * doubleHeight) - (4.330 * doubleAge)
    }
    
    return Int(calculated)
}

func getBudgieGreeting() -> String {
    let greetingArray = ["Hi.", "Hello.", "Cheep.", "Tweet.", "Chirp.", "Aah! You found me!", "...moo?"]
    
    return greetingArray.randomElement()!
}

// WEIGHT RELATED STRUCTS/FUNCTIONS
/// Hardcoded constant of the amount in kg of a lb.
let lbInKg: Double = 0.45359237
/// Hardcoded constant of the amount in kg of a st.
let stInKg: Double = lbInKg * 14

/// Enum detailing different options for weights - kilograms, plain pounds or British-style stones and pounds.
enum weightUnits: Int {
    case kilograms = 0
    case pounds = 1
    case stonepounds = 2
}

/// Struct that simplifies conversions between kilograms (as used on the back-end), stones and stones and pounds.
struct StonePounds {
    init(kilos: Double) {
        self.kilos = kilos
    }

    init(stones: Int, pounds: Int) {
        self.kilos = Double((stones * 14) + pounds) * lbInKg
    }
    
    var kilos: Double
    
    var totalPounds: Int {
        get { Int((kilos / lbInKg).rounded()) }
        set { kilos = Double(newValue) * lbInKg }
    }
    
    var stones: Int {
        get { totalPounds / 14 }
        set { totalPounds = (newValue * 14) + pounds }
    }
    
    var pounds: Int {
        get { totalPounds % 14 }
        set { totalPounds = (stones * 14) + newValue }
    }
    
    var string: String {
        switch (stones, pounds) {
        case (0, 0):
            return "0lb"
        case (_, 0):
            return "\(stones.formatted())st"
        case (0, _):
            return "\(pounds.formatted())lb"
        default:
            return "\(stones.formatted())st \(pounds.formatted())lb"
        }
    }
}

/// Renders a weight given in kilograms into a formatted string either depending on a function argument, or the user's settings. By default, includes a suffix, but can optionally not have one (although this does not work for stones and pounds as this does not make sense.)
func renderWeight(kilos: Double, outputUnit: weightUnits? = nil, includeSuffix: Bool? = true) -> String {
    let usedOutputUnit = outputUnit ?? weightUnits(rawValue: settingsObj.weightDisplayUnit) ?? .kilograms
    var returnString: String = ""
    
    switch usedOutputUnit {
        case .kilograms: returnString = roundDoubleWeight(input: kilos).formatted()
        case .pounds: returnString = roundDoubleWeight(input: kilos / lbInKg).formatted()
        case .stonepounds: returnString = StonePounds(kilos: kilos).string // stonepounds doesn't make sense without units
    }
    
    if includeSuffix == true {
        switch usedOutputUnit {
            case .kilograms: returnString += "kg"
            case .pounds: returnString += "lbs"
            case .stonepounds: break
        }
    }
    
    return returnString
}

// VOLUME RELATED STRUCTS/FUNCTIONS
/// Enum detailing volume options - millilitres, US fluid ounces or British (imperial) fluid ounces.
enum volumeUnits: Int {
    case millilitres = 0
    case usFluidOunces = 1
    case imperialFluidOunces = 2

    /// Millilitres in one unit of this measure (1 for millilitres themselves).
    var millilitresPerUnit: Double {
        switch self {
            case .millilitres:         return 1
            case .usFluidOunces:       return 29.5735
            case .imperialFluidOunces: return 28.4130625
        }
    }

    /// Suffix appended when rendering a value in this unit.
    var suffix: String {
        switch self {
            case .millilitres:                            return "ml"
            case .usFluidOunces, .imperialFluidOunces:    return "fl oz"
        }
    }

    /// Human-readable name for pickers.
    var pickerLabel: String {
        switch self {
            case .millilitres:         return "Millilitres"
            case .usFluidOunces:       return "US fluid ounces"
            case .imperialFluidOunces: return "Imperial fluid ounces"
        }
    }
}

/// Converts a value expressed in the given volume unit into whole millilitres for storage.
func millilitres(from displayValue: Double, in unit: volumeUnits) -> Int {
    Int((displayValue * unit.millilitresPerUnit).rounded())
}

/// Renders a volume given in millilitres into a formatted string, either using a supplied unit or the user's setting. Includes a suffix by default.
func renderVolume(millilitres ml: Int, outputUnit: volumeUnits? = nil, includeSuffix: Bool = true) -> String {
    let usedUnit = outputUnit ?? volumeUnits(rawValue: settingsObj.waterDisplayUnit) ?? .millilitres
    var returnString: String

    switch usedUnit {
        case .millilitres:
            returnString = ml.formatted()
        case .usFluidOunces, .imperialFluidOunces:
            returnString = (Double(ml) / usedUnit.millilitresPerUnit)
                .formatted(.number.precision(.fractionLength(0...1)))
    }

    if includeSuffix {
        // Millilitres sit flush ("250ml"); fluid ounces read better spaced ("8.5 fl oz").
        returnString += (usedUnit == .millilitres ? "" : " ") + usedUnit.suffix
    }

    return returnString
}

// BLOB FUNCTIONS
/// Colour of the central blob, based on how much the user can still eat.
func budgetBlobColour(canEatNow: Int, surplusMode: Bool = settingsObj.surplusMode) -> Color {
    if canEatNow < -49 {
        return surplusMode ? .green : .red
    } else if canEatNow < 50 {
        return surplusMode ? .red : .green
    } else {
        return .teal
    }
}

/// Colour of the progress ring. `diff` is the caller's progress metric (1.0 == on pace).
func budgetPathColour(diff: Double, budget: Int, projectedBasal: Int) -> Color {
    if diff < 0.25 {
        return .blue
    } else if diff < 1.05 {
        return .green
    } else if diff < 1.20 {
        // A little over, but fine if the overage is smaller than the resting calories left to burn.
        return (diff - 1) * Double(budget) < Double(projectedBasal) ? .green : .yellow
    } else {
        return .red          // ← single source of truth; fixes the watch's yellow "bad" bug
    }
}

/// Headline label above the meter.
func budgetStatusLabel(leftToEat: Int, surplusMode: Bool = settingsObj.surplusMode, usingAllocations: Bool = settingsObj.useMealAllocations) -> String {
    if surplusMode {
        return leftToEat > -1 ? "Left to eat" : "Over target by"
    } else if usingAllocations {
        // Allocations pace by meal, so the blob shows the plain daily remainder — not a paced "can eat now".
        return leftToEat > -1 ? "Left today" : "Over budget by"
    } else {
        return leftToEat > -1 ? "Can eat now" : "Over target by"
    }
}

extension Binding where Value == Double? {
    /// Bridges an optional Double to a text field: blank means "not recorded" (nil), not zero — so a macro left empty stays absent rather than logged as 0 g. Accepts a comma or a point as the decimal separator.
    var optionalNumberText: Binding<String> {
        Binding<String>(
            get: {
                guard let v = wrappedValue else { return "" }
                return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
            },
            set: { str in
                let cleaned = str.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
                wrappedValue = cleaned.isEmpty ? nil : Double(cleaned)
            }
        )
    }
}
