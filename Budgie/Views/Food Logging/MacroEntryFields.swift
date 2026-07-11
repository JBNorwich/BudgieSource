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

/// Three optional macro entry rows (protein / carbs / fat). A blank field means "not recorded" (nil),
/// not zero — so an untouched macro stays absent rather than being logged as 0 g.
struct MacroEntryFields: View {
    @Binding var protein: Double?
    @Binding var carbs: Double?
    @Binding var fat: Double?

    var body: some View {
        macroField("Protein", value: $protein)
        macroField("Carbs", value: $carbs)
        macroField("Fat", value: $fat)
    }

    @ViewBuilder
    private func macroField(_ label: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: optionalNumberText(value))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text("g")
        }
    }

    private func optionalNumberText(_ value: Binding<Double?>) -> Binding<String> {
        Binding(
            get: {
                guard let v = value.wrappedValue else { return "" }
                return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
            },
            set: { str in
                let cleaned = str.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
                value.wrappedValue = cleaned.isEmpty ? nil : Double(cleaned)
            }
        )
    }
}
