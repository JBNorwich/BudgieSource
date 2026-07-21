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

/// Identifies which of `WeightUnitEntryFields`' fields has focus.
enum WeightEntryField { case kilos, pounds, stones, poundsPart }

/// The weight-unit entry row: kg, lbs, or st + lb, whichever the user has currently chosen — shared by
/// every screen that lets the user type in a weight (logging a weight, setting a weight goal).
struct WeightUnitEntryFields: View {
    var unit: weightUnits
    /// Shown in the kg/lbs field when empty — e.g. "Weight" or "Goal".
    var placeholder: String
    @Binding var kilos: Double?
    @Binding var pounds: Double?
    @Binding var stones: Int?
    @Binding var poundsPart: Int?
    var focus: FocusState<WeightEntryField?>.Binding

    var body: some View {
        switch unit {
        case .kilograms:
            HStack {
                TextField(placeholder, value: $kilos, format: .number)
                    .font(.largeTitle)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .focused(focus, equals: .kilos)
                Text("kg").font(.largeTitle).foregroundStyle(.secondary)
            }
        case .pounds:
            HStack {
                TextField(placeholder, value: $pounds, format: .number)
                    .font(.largeTitle)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .focused(focus, equals: .pounds)
                Text("lbs").font(.largeTitle).foregroundStyle(.secondary)
            }
        case .stonepounds:
            HStack {
                TextField("0", value: $stones, format: .number)
                    .font(.largeTitle)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    .focused(focus, equals: .stones)
                Text("st").font(.largeTitle).foregroundStyle(.secondary)
                TextField("0", value: $poundsPart, format: .number)
                    .font(.largeTitle)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    .focused(focus, equals: .poundsPart)
                Text("lb").font(.largeTitle).foregroundStyle(.secondary)
            }
        }
    }
}
