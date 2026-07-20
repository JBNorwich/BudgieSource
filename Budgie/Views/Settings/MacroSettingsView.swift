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

/// Settings for the optional macro feature: a master on/off, and an optional daily goal expressed either as fixed grams or as a percentage split of the calorie budget. Neutral throughout — a goal is the user's own target, never suggested, and nothing here frames macros in terms of body composition.
struct MacroSettingsView: View {
    @EnvironmentObject var todayLump: TodayLump
    @State private var refreshID = UUID()
    @FocusState private var fieldFocused: Bool

    private static let gramsFormat: IntegerFormatStyle<Int> = .number.precision(.integerLength(1...4))
    private static let percentFormat: IntegerFormatStyle<Int> = .number.precision(.integerLength(1...3))

    private var enabledBinding: Binding<Bool> {
        Binding(get: { !settingsObj.disableMacros },
                set: { settingsObj.disableMacros = !$0; refreshID = UUID() })
    }

    private var percentTotal: Int {
        settingsObj.proteinPercent + settingsObj.carbsPercent + settingsObj.fatPercent
    }

    var body: some View {
        let _ = refreshID   // observe so a setting change redraws the form
        Form {
            Section(header: Text("What are macros?")) {
                Text("Macros are the three nutrients that make up the calories in your food: **protein**, **carbohydrate** and **fat**.\n\nA goal is optional. You can set it in grams, or as a percentage of your daily budget — Budgie Diet then works out the grams for you (at 4 calories per gram for protein and carbs, and 9 for fat). Each ring on the Today screen fills as you log food and simply keeps counting if you go past a goal. If you'd rather not track them, you can turn macros off.")
                    .multilineTextAlignment(.leading)
            }
            
            Section(footer: Text("Shows the protein, carbohydrate and fat in what you log, above your food list. Turn it off to hide this.")) {
                Toggle("Track macros", isOn: enabledBinding)
            }

            if !settingsObj.disableMacros {
                Section(header: Text("Daily goal"), footer: Text(goalFooter)) {
                    Picker("Goal", selection: settingBinding(\.macroGoalMode, refresh: $refreshID)) {
                        Text("None").tag(0)
                        Text("By grams").tag(1)
                        Text("By percentage").tag(2)
                    }
                }

                if settingsObj.macroGoalMode == 1 {
                    Section(footer: Text("Leave a macro at 0 to just see its total, without a ring.")) {
                        gramsField("Protein", \.proteinGoalGrams)
                        gramsField("Carbs", \.carbsGoalGrams)
                        gramsField("Fat", \.fatGoalGrams)
                    }
                } else if settingsObj.macroGoalMode == 2 {
                    Section(footer: Text(percentFooter)) {
                        percentField("Protein", \.proteinPercent)
                        percentField("Carbs", \.carbsPercent)
                        percentField("Fat", \.fatPercent)
                        Button("Reset to default split") {
                            settingsObj.proteinPercent = 30
                            settingsObj.carbsPercent = 40
                            settingsObj.fatPercent = 30
                            refreshID = UUID()
                        }
                    }
                }
            }
        }
        .navigationTitle("Macros")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { fieldFocused = false }
            }
        }
    }

    @ViewBuilder
    private func gramsField(_ label: String, _ keyPath: ReferenceWritableKeyPath<CloudSettings, Int>) -> some View {
        LabeledContent {
            TextField("0", value: settingBinding(keyPath, refresh: $refreshID), format: MacroSettingsView.gramsFormat)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .focused($fieldFocused)
        } label: { Text("\(label) (g)") }
    }

    @ViewBuilder
    private func percentField(_ label: String, _ keyPath: ReferenceWritableKeyPath<CloudSettings, Int>) -> some View {
        LabeledContent {
            HStack(spacing: 2) {
                TextField("0", value: settingBinding(keyPath, refresh: $refreshID), format: MacroSettingsView.percentFormat)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .focused($fieldFocused)
                    .frame(maxWidth: 55)
                Text("%").foregroundStyle(.secondary)
            }
        } label: { Text(label) }
    }

    private var goalFooter: String {
        switch settingsObj.macroGoalMode {
        case 1: return "Set a fixed daily target in grams for each macro you want to track."
        case 2: return "Set each macro as a share of your daily calorie budget, so the gram targets flex with your budget. A balanced starting point is offered; adjust it however you like."
        default: return "With no goal, macros show as running totals for the day."
        }
    }

    private var percentFooter: String {
        var parts: [String] = []
        if percentTotal != 100 {
            parts.append("These currently add up to \(percentTotal)%. They work best totalling 100%.")
        }
        let goals = settingsObj.macroGoalGrams(budget: todayLump.totalBudget)
        if let p = goals.protein, let c = goals.carbs, let f = goals.fat {
            parts.append("At today's budget that's about \(p) g protein, \(c) g carbs and \(f) g fat.")
        }
        return parts.joined(separator: " ")
    }
}
