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

/// Eaten ÷ target, clamped to 0...2 — shared by `TodayLump.progressAgainstTarget` and the widget's
/// per-entry equivalent, so both compute the same ring-colour figure the same way.
func clampedProgress(eaten: Int, target: Int) -> Double {
    guard target != 0 else { return 0 }
    return min(max(Double(eaten) / Double(target), 0), 2)
}

extension Double {
    /// Safe Double → Int for user-entered or scaled values (e.g. a serving amount multiplied through
    /// a food's stamped calories/macros): clamps non-finite or out-of-range doubles instead of
    /// trapping, unlike `Int(_:)`, which crashes on NaN, ±infinity, or anything outside Int's range.
    var safeInt: Int {
        guard isFinite else { return 0 }
        return Int(max(Double(Int.min), min(Double(Int.max), self)).rounded())
    }
}

/// Resolves whichever unit's fields the user actually entered into kilograms. `nil` means nothing
/// meaningful was entered for that unit (not zero) — shared by the weight-log and weight-goal sheets,
/// which otherwise each carried an identical copy of this per-unit dispatch.
func kilograms(kg: Double?, lb: Double?, st: Int?, stLb: Int?, unit: weightUnits) -> Double? {
    switch unit {
    case .kilograms:
        return kg
    case .pounds:
        guard let lb else { return nil }
        return lb * lbInKg
    case .stonepounds:
        let s = st ?? 0, p = stLb ?? 0
        guard s != 0 || p != 0 else { return nil }
        return StonePounds(stones: s, pounds: p).kilos
    }
}

/// A two-way binding onto a `CloudSettings` property that also bumps `refresh` on write, forcing a
/// redraw — `CloudSettings` isn't `ObservableObject` (it's a thin wrapper over iCloud key-value
/// storage), so views that bind directly to it need this to pick up their own writes. Shared by every
/// settings screen, which otherwise each declared their own identical copy of this.
func settingBinding<T>(_ keyPath: ReferenceWritableKeyPath<CloudSettings, T>, refresh: Binding<UUID>) -> Binding<T> {
    Binding(
        get: { settingsObj[keyPath: keyPath] },
        set: { settingsObj[keyPath: keyPath] = $0; refresh.wrappedValue = UUID() }
    )
}

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

/// Case-insensitive substring matches for manufacturer autocomplete, excluding an exact match
/// (nothing to suggest once it's been typed in full). Shared by every food-entry sheet.
func suggestedManufacturers(for query: String, in known: [String], limit: Int = 5) -> [String] {
    let q = query.trimmingCharacters(in: .whitespaces)
    guard !q.isEmpty else { return [] }
    return known
        .filter { $0.localizedCaseInsensitiveContains(q) && $0.localizedCaseInsensitiveCompare(q) != .orderedSame }
        .prefix(limit).map { $0 }
}

/// A compact "P Xg · C Xg · F Xg" line, listing only the macros that were actually recorded
/// (rounded to whole grams). Shared by every place that previews or displays an entry's macros.
func macroSummary(protein: Double?, carbs: Double?, fat: Double?) -> String {
    [("P", protein), ("C", carbs), ("F", fat)]
        .compactMap { label, value in value.map { "\(label) \($0.safeInt)g" } }
        .joined(separator: " · ")
}

/// Resolves the food behind a logged entry so re-adding it behaves like a fresh log: the saved
/// FoodItem, the bundled generic (by name), or a one-serving reconstruction from the entry's own
/// stamp. Shared by the iOS and Mac add-food sheets.
func resolveFood(for entry: CalorieEntry) async -> PickedFood? {
    if let id = entry.foodItem, let food = await dataStore.foodItemActor.fetch(id: id) {
        return food.asPicked
    }
    guard let unit = entry.servingUnit else { return nil }   // no serving stamp → genuine quick entry
    let name = entry.narrative ?? ""
    let entryManufacturer = entry.manufacturer ?? ""
    if let match = FoodCatalogue.shared.search(name).first(where: {
        let nameMatches = $0.name.caseInsensitiveCompare(name) == .orderedSame
        let manufacturerMatches = ($0.manufacturer ?? "").caseInsensitiveCompare(entryManufacturer) == .orderedSame
        return nameMatches && manufacturerMatches
    }) {
        return match.asPicked
    }
    let q = FoodQuantity(type: unit, count: entry.servingAmount ?? 1, calories: entry.calories,
                         protein: entry.protein, carbs: entry.carbs, fat: entry.fat)
    return PickedFood(id: UUID(), persistedID: nil, name: name.isEmpty ? "Food" : name,
                      manufacturer: entry.manufacturer, quantities: [q])
}

/// Best serving to re-open a past logged entry on: the one matching the entry's unit and, when
/// several share that unit, the one whose per-unit calorie rate is closest to what was actually
/// logged — so a food with two same-unit servings (e.g. "1 slice" and "1 loaf") re-opens on the one
/// the entry really used, rather than whichever happens to come first. Shared by every screen that
/// re-opens a past CalorieEntry against a food's current servings.
func bestServingIndex(in quantities: [FoodQuantity], forUnit unit: FoodQuantityType?,
                      calories: Int, servingAmount: Double?) -> Int {
    guard let unit else { return 0 }
    let sameUnit = quantities.indices.filter { quantities[$0].type == unit }
    guard let first = sameUnit.first else { return 0 }
    guard let amount = servingAmount, amount > 0 else { return first }
    let loggedRate = Double(calories) / amount
    return sameUnit.min { servingRateGap(quantities[$0], loggedRate) < servingRateGap(quantities[$1], loggedRate) } ?? first
}

/// How far a serving's per-unit calorie rate is from a target rate — used to disambiguate two
/// servings that share a unit type.
private func servingRateGap(_ q: FoodQuantity, _ rate: Double) -> Double {
    guard q.count > 0 else { return .greatestFiniteMagnitude }
    return abs(Double(q.calories) / q.count - rate)
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

/// Single source of truth for both the meter ring colour and the gauge's status label.
enum BudgetStanding {
    case wellUnder, onTarget, slightlyOver, over
    var colour: Color {
        switch self {
        case .wellUnder:    return .blue
        case .onTarget:     return .green
        case .slightlyOver: return .yellow
        case .over:         return .red
        }
    }
}

func budgetStanding(diff: Double, budget: Int, projectedBasal: Int) -> BudgetStanding {
    if diff < 0.25 { return .wellUnder }
    if diff < 1.05 { return .onTarget }
    if diff < 1.20 {
        // a little over, but fine if the overage is under the resting calories left to burn
        return (diff - 1) * Double(budget) < Double(projectedBasal) ? .onTarget : .slightlyOver
    }
    return .over
}

func budgetPathColour(diff: Double, budget: Int, projectedBasal: Int) -> Color {
    budgetStanding(diff: diff, budget: budget, projectedBasal: projectedBasal).colour
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
