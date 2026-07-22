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

private struct SuggestionAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// Marks this field as the anchor for a suggestions dropdown while `active` is true.
    func suggestionAnchor(_ active: Bool) -> some View {
        anchorPreference(key: SuggestionAnchorKey.self, value: .bounds) { active ? $0 : nil }
    }

    /// Draws `items` as a tappable dropdown just below the anchored field. Apply this to a
    /// container OUTSIDE the clipping List/Form (i.e. the view's root) so it isn't clipped.
    func suggestionOverlay(_ items: [String], onSelect: @escaping (String) -> Void) -> some View {
        overlayPreferenceValue(SuggestionAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor, !items.isEmpty {
                    let rect = proxy[anchor]
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(items, id: \.self) { name in
                            Button { onSelect(name) } label: {
                                Text(name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14).padding(.vertical, 11)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if name != items.last { Divider() }
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
                    .shadow(radius: 8, y: 4)
                    .frame(width: rect.width)
                    .offset(x: rect.minX, y: rect.maxY + 4)
                }
            }
        }
    }
}
