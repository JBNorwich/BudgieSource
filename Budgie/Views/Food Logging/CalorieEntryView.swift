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

struct CalorieEntryView: View {
    var calories: Int
    var narrative: String
    var manufacturer: String? = nil
    var protein: Double? = nil
    var carbs: Double? = nil
    var fat: Double? = nil
    var isGeneric: Bool = false
    /// Whether the entry is linked to a saved FoodItem. Separates a saved-food entry (→ "Custom food entry" when it carries no manufacturer) from a plain quick-calorie entry (→ "Quick calories").
    var hasFoodItem: Bool = false
    /// When true (the Food hub's food rows), show the manufacturer/placeholder caption and macro line. Left false elsewhere (Today screen, Health aggregate rows) to keep those plain.
    var detailed: Bool = false

    /// A compact "P 30g · C 40g · F 20g" line, listing only the macros that were recorded.
    private var macroText: String {
        var parts: [String] = []
        if let protein { parts.append("P \(Int(protein.rounded()))g") }
        if let carbs { parts.append("C \(Int(carbs.rounded()))g") }
        if let fat { parts.append("F \(Int(fat.rounded()))g") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if detailed {
                    if let manufacturer, !manufacturer.isEmpty {
                        Text(manufacturer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else if isGeneric {
                        Text("Generic")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if hasFoodItem {
                        Text("Custom food entry")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if narrative.caseInsensitiveCompare("Quick calories") != .orderedSame {
                        // Named quick entry: label the row; skip it when the title is already "Quick calories".
                        Text("Quick calories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(narrative)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if detailed, !macroText.isEmpty {
                    Text(macroText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(calories.formatted())
                .contentTransition(.numericText())
                .layoutPriority(1)          // keep the number right-aligned; the name truncates, not this
        }
    }
}
