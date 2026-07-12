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

let whaleSalutations: [String] =
    ["Hi.",
    "Howdy.",
    "Yo.",
    "Splish splash.",
    "Great progress.",
    "I'm a whale."]

let healthDisclaimer: String = "**IMPORTANT:** Budgie Diet is for information purposes only, and its suggestions are not a substitute for professional medical advice. It's best to consult your doctor before starting any new diet plan."

let weightingText = "This adjusts how predicted active calories are weighted. Most people should stick with the default, but you can change it if you feel your budgets are often too high or low.\n\n**Don't weight down:** Budgie Diet won't weight down its predictions at all. You *probably* don't want to use this, unless you use the Move goal as the basis of your budget and always stick to it.\n\n**Forgiving:** Budgie Diet more strongly adjusts its predictions in the late evening and continues predicting until midnight, while making no adjustments to your average. This works well if you usually exercise in the evening, but it might make your budget higher than it should be otherwise.\n\n**Default:** This balanced setting increases its predictions as you exercise more, preventing your budget from being overestimated on less strenuous days. Most people will find this setting ideal.\n\n**Harsh:** This setting adjusts your budget down very harshly. This is ideal for people who either exercise in the early morning or not at all, but will significantly reduce your budget otherwise.\n\n**No predictions at all:** Budgie Diet won’t estimate active calories for you. Your budget will only include resting calories and any exercise you’ve done. It’ll be very accurate, but might feel a bit restrictive, especially in the morning.\n\n**Default (old):** This is the default in previous versions of Budgie Diet, in case you prefer that."

let cappingText = "This lets you cap your budget, so even if you exercise more than expected, your budget will not exceed this amount (i.e. Budgie Diet will not prompt you to \"eat back\" all the calories you've burned over your averages).\n\n**WARNING:** **Diets based on extreme caloric restriction and/or extreme levels of exercise relative to your food intake are unsustainable, and carry serious health risks.** Budgie Diet is hard-coded to never allow your budget to dip below 1,200kcal per day under any circumstances.\n\nBudgie Diet is for information purposes only, and its suggestions are not a substitute for professional medical advice. Its developer strongly encourages you to discuss any diet plans with a reputable medical professional first, especially if these would involve you eating less than 1,200kcal per day."

let mealTimeText = "Budgie Diet usually weights to ensure that you have your \"full\" remaining budget available to eat after 6pm. If you typically eat dinner at a different time from this, you can change this here."

let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
let versionString = "Version \(appVersion) (Build \(appBuild))"
let copyrightString = "Copyright 2024- Joe Baldwin"

/// Bump this ONLY for releases with major new features (not bug-fix point releases). It drives the "What's New" sheet and is the value written to `settingsObj.lastOpenedVersion` once seen. Keep it "major.minor" so the numeric string comparison behaves.
let whatsNewVersion = "3.3"

struct WhatsNewItem: Identifiable {
    let id = UUID()
    let icon: String     // SF Symbol
    let title: String
    let detail: String
}

/// The items shown for `whatsNewVersion`. EDIT this list (and bump `whatsNewVersion`) each major release.
let whatsNewItems: [WhatsNewItem] = [
    WhatsNewItem(icon: "carrot.fill",
                 title: "Food logging, improved!",
                 detail: "Log and track individual food items with varying portion sizes! All your food entries have been moved across too - you can edit them however you like, just go to \"Food\" and tap the carrot icon!"),
    WhatsNewItem(icon: "chart.pie",
                 title: "Track your macros!",
                 detail: "Optionally track your macros, and set a goal for yourself based on either percentages of your budget or grams! If you don't want to, turn it off in Settings!"),
    WhatsNewItem(icon: "globe",
                 title: "Search for food items!",
                 detail: "You can now search OpenFoodFacts for calorie and macro information! Completely optional and with no registration needed!"),
    WhatsNewItem(icon: "clock",
                 title: "Still like quick calories? No problem!",
                 detail: "All of this is optional - you can still enter quick calories just as you did before!")
]

/// Whether the "What's New" sheet should appear: setup is finished and the user hasn't yet seen this version's sheet.
func shouldShowWhatsNew() -> Bool {
    guard !settingsObj.isFirstRun, !whatsNewItems.isEmpty else { return false }
    return settingsObj.lastOpenedVersion.compare(whatsNewVersion, options: .numeric) == .orderedAscending
}
