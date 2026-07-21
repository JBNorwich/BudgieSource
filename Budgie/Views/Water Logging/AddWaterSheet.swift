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

struct AddWaterSheet: View {
    @Binding var isDisplayed: Bool

    var dateToAddOn: Date
    @State var amount: Int?          // entered in the user's chosen volume unit
    @State var amountWasZero: Bool = false
    @State private var isSaving: Bool = false
    @FocusState var isFocused: Bool

    private var unit: volumeUnits {
        volumeUnits(rawValue: settingsObj.waterDisplayUnit) ?? .millilitres
    }

    /// Quick-add presets, expressed in the current display unit.
    private var quickAmounts: [Int] {
        unit == .millilitres ? [250, 500, 750, 1000] : [8, 16, 24, 32]
    }

    private let quickImages = ["mug.fill", "waterbottle", "waterbottle.fill", "waterbottle.fill"]

    /// Logs `displayAmount` (in the current display unit) and dismisses — shared by the manual "Add"
    /// button and every quick-add preset, so the save/dismiss sequence only lives in one place.
    private func logWater(_ displayAmount: Int) {
        isSaving = true
        Task {
            await dataStore.addWater(amount: millilitres(from: Double(displayAmount), in: unit), datetime: dateToAddOn)
            isDisplayed = false
        }
    }

    struct QuickWaterButton: View {
        let image: String
        let displayAmount: Int
        let unit: volumeUnits
        let isSaving: Bool
        let onTap: () -> Void

        private var label: String {
            unit == .millilitres ? "\(displayAmount)ml" : "\(displayAmount) fl oz"
        }

        var body: some View {
            VStack {
                Button(label, systemImage: image, action: onTap)
                    .buttonStyle(.bordered)
                    .controlSize(.extraLarge)
                    .buttonBorderShape(.circle)
                    .labelStyle(.iconOnly)
                    .disabled(isSaving)
                Text(label)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Amount", value: $amount, format: .number)
                            .font(.largeTitle)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                        Text(unit.suffix)
                            .font(.largeTitle)
                        Button("Add") {
                            guard let amount, amount > 0 else {
                                amountWasZero = true
                                isFocused = true
                                return
                            }
                            logWater(amount)
                        }.buttonStyle(.borderedProminent).disabled(isSaving)
                    }
                }

                Section(header: Text("Quick add")) {
                    HStack {
                        ForEach(Array(quickAmounts.enumerated()), id: \.offset) { index, qa in
                            if index != 0 { Spacer() }
                            QuickWaterButton(image: quickImages[min(index, quickImages.count - 1)],
                                             displayAmount: qa,
                                             unit: unit,
                                             isSaving: isSaving,
                                             onTap: { logWater(qa) })
                        }
                    }
                }
            }
            .navigationTitle("Add water")
            .keyboardDoneButton($isFocused)
        }
        .okAlert("Amount must be above zero.", isPresented: $amountWasZero)
    }
}
