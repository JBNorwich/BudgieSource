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
import UIKit

struct FoodEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let existingID: UUID?
    private let prefilledBarcode: String?
    private let onSaved: ((PickedFood) -> Void)?
    @State private var name: String
    @State private var manufacturer: String
    @State private var quantities: [FoodQuantity]
    private let isModal: Bool
    @FocusState private var manufacturerFocused: Bool
    @State private var knownManufacturers: [String] = []
    @State private var isSaving = false

    /// Pass an existing item to edit it, or nothing to create a new one. `prefilledBarcode` stamps a
    /// barcode onto a newly created food (so a future scan resolves it locally); `onSaved` hands the
    /// created food back to a caller that wants to log it immediately.
    init(existing: FoodItem? = nil, isModal: Bool = false,
         prefilledBarcode: String? = nil, onSaved: ((PickedFood) -> Void)? = nil) {
        self.existingID = existing?.id
        self.isModal = isModal
        self.prefilledBarcode = prefilledBarcode
        self.onSaved = onSaved
        _name = State(initialValue: existing?.name ?? "")
        _manufacturer = State(initialValue: existing?.manufacturer ?? "")
        let qs = existing?.quantities ?? []
        _quantities = State(initialValue: qs.isEmpty
            ? [FoodQuantity(type: .grams, count: 100, calories: 0)]
            : qs)
    }

    var canSave: Bool {
        !isSaving
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !quantities.isEmpty
            && quantities.allSatisfy {
                $0.count > 0 && $0.calories >= 0
                    && ($0.protein ?? 0) >= 0 && ($0.carbs ?? 0) >= 0 && ($0.fat ?? 0) >= 0
            }
    }

    private var manufacturerSuggestions: [String] {
        suggestedManufacturers(for: manufacturer, in: knownManufacturers)
    }

    var body: some View {
        // suggestionOverlay must sit outside the clipping Form (per SuggestionAnchorKey's own
        // documented convention, already followed by AddCalsSheet/EditCalsSheet) or the manufacturer
        // dropdown gets clipped away instead of floating over the form.
        Group {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Manufacturer (optional)", text: $manufacturer)
                        .focused($manufacturerFocused)
                        .suggestionAnchor(manufacturerFocused && !manufacturerSuggestions.isEmpty)
                }

                ForEach(quantities.indices, id: \.self) { i in
                    Section("Serving \(i + 1)") {
                        servingEditor(i)
                        if quantities.count > 1 {
                            Button("Remove serving", role: .destructive) {
                                quantities.remove(at: i)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        quantities.append(FoodQuantity(type: .grams, count: 100, calories: 0))
                    } label: {
                        Label("Add serving", systemImage: "plus")
                    }
                }
            }
        }
        .navigationTitle(existingID == nil ? "New food" : "Edit food")
        .editorToolbar(isModal: isModal, canSave: canSave, isSaving: $isSaving) { await save() }
        // For a brand-new food the amount (100) and calories (0) start pre-filled; select the value
        // on focus so the user types straight over it. Empty fields (name, macros…) are unaffected,
        // and editing an existing food is left alone so a partial edit isn't wiped.
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
            guard existingID == nil, let field = note.object as? UITextField else { return }
            DispatchQueue.main.async {
                field.selectedTextRange = field.textRange(from: field.beginningOfDocument,
                                                          to: field.endOfDocument)
            }
        }
        .suggestionOverlay(manufacturerSuggestions) { manufacturer = $0 }
        .task { knownManufacturers = await dataStore.knownManufacturers() }
    }

    @ViewBuilder
    private func servingEditor(_ i: Int) -> some View {
        Picker("Measured in", selection: $quantities[i].type) {
            Text("Grams").tag(FoodQuantityType.grams)
            Text("Millilitres").tag(FoodQuantityType.millilitres)
            Text("Portion").tag(FoodQuantityType.portion)
        }
        .pickerStyle(.menu)

        TextField("Serving name (optional), e.g. “1 medium banana”",
                  text: Binding(get: { quantities[i].servingName ?? "" },
                                set: { quantities[i].servingName = $0.isEmpty ? nil : $0 }))

        LabeledDoubleRow(label: quantities[i].type == .portion ? "Portions" : "Amount",
                        value: $quantities[i].count,
                        suffix: quantities[i].type != .portion ? quantities[i].type.unitName : nil)

        LabeledIntRow(label: "Calories", value: $quantities[i].calories, suffix: "kcal")

        DisclosureGroup("Nutrition (optional)") {
            MacroEntryFields(protein: $quantities[i].protein, carbs: $quantities[i].carbs, fat: $quantities[i].fat)
        }
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let mfr = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMfr = mfr.isEmpty ? nil : mfr

        if let existingID {
            await dataStore.foodItemActor.update(id: existingID, name: trimmedName,
                                                 manufacturer: cleanMfr, quantities: quantities)
            await dataStore.calorieActor.relabelEntries(forFood: existingID, name: trimmedName,
                                                        manufacturer: cleanMfr)
        } else {
            let item = FoodItem(name: trimmedName, manufacturer: cleanMfr,
                                quantities: quantities, source: .userInput)
            item.barcode = prefilledBarcode
            let saved = await dataStore.foodItemActor.insert(item)
            onSaved?(saved.asPicked)
        }
        if cleanMfr != nil { await dataStore.invalidateManufacturersCache() }
    }
}

#Preview {
    NavigationStack {
        FoodEditorView()
    }
}
