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
            TextField("—", text: value.optionalNumberText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text("g")
        }
    }
}

extension Array {
    /// Safe indexed access — nil instead of crashing when `index` is out of bounds.
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// A picked serving's amount expressed as a fraction of servings — 0 when there's no serving to scale
/// from (e.g. the underlying food was removed). Shared by every screen that scales a food serving by amount.
func servingsScaled(_ quantity: FoodQuantity?, amount: Double) -> Double {
    guard let quantity, quantity.count > 0 else { return 0 }
    return amount / quantity.count
}

/// A "label ... value [suffix]" form row with a trailing-aligned decimal field — the shape repeated
/// across every food-entry and food-editor screen. `width` matches the field's usual 90pt, but stays
/// overridable for a screen with a deliberately narrower value (e.g. a batch yield count).
struct LabeledDoubleRow: View {
    var label: String
    @Binding var value: Double
    var suffix: String?
    var width: CGFloat = 90
    var focus: FocusState<Bool>.Binding?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Group {
                if let focus {
                    field.focused(focus)
                } else {
                    field
                }
            }
            if let suffix { Text(suffix) }
        }
    }

    private var field: some View {
        TextField("", value: $value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: width)
    }
}

/// Same shape as `LabeledDoubleRow`, for a whole-number field (e.g. calories) with a number-pad keyboard.
struct LabeledIntRow: View {
    var label: String
    @Binding var value: Int
    var suffix: String?
    var width: CGFloat = 90

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: width)
            if let suffix { Text(suffix) }
        }
    }
}

/// Picker for choosing which of a food's servings a form is scaling — shared by every screen that
/// scales a food serving (adding, editing, or picking a meal ingredient). Resets `amount` to the new
/// serving's reference count on change, since the old amount is meaningless once the unit changes.
struct ServingPicker: View {
    var quantities: [FoodQuantity]
    @Binding var selectedIndex: Int
    @Binding var amount: Double

    var body: some View {
        Picker("Serving", selection: Binding(
            get: { selectedIndex },
            set: { newIndex in
                selectedIndex = newIndex
                if let q = quantities[safe: newIndex] { amount = q.count }
            }
        )) {
            ForEach(quantities.indices, id: \.self) { i in
                Text(quantities[i].label).tag(i)
            }
        }
        .pickerStyle(.menu)
    }
}

/// Search-result row for a `PickedFood`: name (+ "Generic" badge), then a manufacturer/serving
/// caption, with the first serving's calories on the trailing edge. Shared by every food search list.
struct PickedFoodRow: View {
    var food: PickedFood
    var onTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(food.name).lineLimit(1).truncationMode(.tail)
                    if food.isGeneric {
                        Text("Generic").font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                let caption = [food.manufacturer, food.quantities.first?.label]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                if !caption.isEmpty {
                    Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                }
            }
            Spacer()
            if let first = food.quantities.first {
                Text("\(first.calories.formatted()) kcal").foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

/// The "Search OpenFoodFacts" prompt shown beneath a food search's results, when that feature hasn't
/// been turned off — shared by every screen that searches for a food to log or add as an ingredient.
@ViewBuilder
func openFoodFactsSearchSection(showing: Binding<Bool>) -> some View {
    if !settingsObj.offSearchDisabled {
        Section {
            Button {
                showing.wrappedValue = true
            } label: {
                Label("Search OpenFoodFacts", systemImage: "globe")
            }
        } footer: {
            Text("Not finding it in your foods? Search the OpenFoodFacts database.")
        }
    }
}

private struct EditorToolbarModifier: ViewModifier {
    var isModal: Bool
    var canSave: Bool
    @Binding var isSaving: Bool
    var save: () async -> Void
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.toolbar {
            if isModal {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    isSaving = true
                    Task {
                        await save()
                        dismiss()
                    }
                }.disabled(!canSave)
            }
        }
    }
}

extension View {
    /// Standard Cancel/Save sheet toolbar shared by every food/meal editor: Cancel (shown only when
    /// `isModal`) dismisses immediately; Save runs `save()` then dismisses, disabled while `!canSave`.
    func editorToolbar(isModal: Bool, canSave: Bool, isSaving: Binding<Bool>, save: @escaping () async -> Void) -> some View {
        modifier(EditorToolbarModifier(isModal: isModal, canSave: canSave, isSaving: isSaving, save: save))
    }
}
