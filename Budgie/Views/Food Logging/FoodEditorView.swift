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

struct FoodEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let existingID: UUID?
    @State private var name: String
    @State private var manufacturer: String
    @State private var quantities: [FoodQuantity]

    /// Pass an existing item to edit it, or nothing to create a new one.
    init(existing: FoodItem? = nil) {
        self.existingID = existing?.id
        _name = State(initialValue: existing?.name ?? "")
        _manufacturer = State(initialValue: existing?.manufacturer ?? "")
        let qs = existing?.quantities ?? []
        _quantities = State(initialValue: qs.isEmpty
            ? [FoodQuantity(type: .grams, count: 100, calories: 0)]
            : qs)
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !quantities.isEmpty
    }

    var body: some View {
        Form {
            Section("Food") {
                TextField("Name", text: $name)
                TextField("Manufacturer (optional)", text: $manufacturer)
            }

            Section("Servings") {
                ForEach(quantities.indices, id: \.self) { i in
                    servingEditor(i)
                }
                .onDelete { quantities.remove(atOffsets: $0) }

                Button {
                    quantities.append(FoodQuantity(type: .grams, count: 100, calories: 0))
                } label: {
                    Label("Add serving", systemImage: "plus")
                }
            }
        }
        .navigationTitle(existingID == nil ? "New food" : "Edit food")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await save()
                        dismiss()
                    }
                }.disabled(!canSave)
            }
        }
    }

    @ViewBuilder
    private func servingEditor(_ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Measured in", selection: $quantities[i].type) {
                Text("Grams").tag(FoodQuantityType.grams)
                Text("Millilitres").tag(FoodQuantityType.millilitres)
                Text("Portion").tag(FoodQuantityType.portion)
            }
            .pickerStyle(.menu)

            HStack {
                Text(quantities[i].type == .portion ? "Portions" : "Amount")
                Spacer()
                TextField("", value: $quantities[i].count, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                if quantities[i].type != .portion { Text(quantities[i].type.unitName) }
            }

            HStack {
                Text("Calories")
                Spacer()
                TextField("", value: $quantities[i].calories, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                Text("kcal")
            }

            DisclosureGroup("Nutrition (optional)") {
                macroField("Protein", value: $quantities[i].protein)
                macroField("Carbs", value: $quantities[i].carbs)
                macroField("Fat", value: $quantities[i].fat)
            }
        }
        .padding(.vertical, 4)
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

    /// Bridges an optional Double to a text field: blank means "not recorded" (nil), not zero —
    /// so a macro the user leaves empty stays absent rather than being logged as 0 g.
    private func optionalNumberText(_ value: Binding<Double?>) -> Binding<String> {
        Binding(
            get: {
                guard let v = value.wrappedValue else { return "" }
                return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
            },
            set: { str in
                let cleaned = str.replacingOccurrences(of: ",", with: ".")
                    .trimmingCharacters(in: .whitespaces)
                value.wrappedValue = cleaned.isEmpty ? nil : Double(cleaned)
            }
        )
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let mfr = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMfr = mfr.isEmpty ? nil : mfr

        if let existingID {
            await dataStore.foodItemActor.update(id: existingID, name: trimmedName,
                                                 manufacturer: cleanMfr, quantities: quantities)
        } else {
            let item = FoodItem(name: trimmedName, manufacturer: cleanMfr,
                                quantities: quantities, source: .userInput)
            await dataStore.foodItemActor.insert(item)
        }
    }
}

#Preview {
    NavigationStack {
        FoodEditorView()
    }
}
