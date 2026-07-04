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

struct MacAddWaterSheet: View {
    @EnvironmentObject private var todayLump: TodayLump
    @Environment(\.dismiss) private var dismiss

    let dateToAddOn: Date
    var onSave: () async -> Void = {}

    @State private var amount: Int?
    @State private var amountWasZero = false

    private var unit: volumeUnits { volumeUnits(rawValue: settingsObj.waterDisplayUnit) ?? .millilitres }
    private var quickAmounts: [Int] { unit == .millilitres ? [250, 500, 750, 1000] : [8, 16, 24, 32] }
    private let quickImages = ["mug.fill", "waterbottle", "waterbottle.fill", "waterbottle.fill"]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack {
                        TextField("Amount", value: $amount, format: .number)
                            .textFieldStyle(.roundedBorder).font(.title2)
                        Text(unit.suffix).font(.title2).foregroundStyle(.secondary)
                    }
                }
                Section("Quick add") {
                    HStack {
                        ForEach(Array(quickAmounts.enumerated()), id: \.offset) { index, qa in
                            VStack {
                                Button { add(displayAmount: qa) } label: {
                                    Image(systemName: quickImages[min(index, quickImages.count - 1)]).font(.title2)
                                }
                                .buttonStyle(.bordered).controlSize(.large).buttonBorderShape(.circle)
                                Text(unit == .millilitres ? "\(qa)ml" : "\(qa) fl oz").font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") { add(displayAmount: amount ?? 0) }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 420, height: 320)
        .alert("Amount must be above zero.", isPresented: $amountWasZero) { Button("OK", role: .cancel) {} }
    }

    private func add(displayAmount: Int) {
        guard displayAmount > 0 else { amountWasZero = true; return }
        Task {
            await dataStore.addWater(amount: millilitres(from: Double(displayAmount), in: unit), datetime: dateToAddOn)
            await dataStore.updateLump(todayLump: todayLump)
            await onSave()
            dismiss()
        }
    }
}
