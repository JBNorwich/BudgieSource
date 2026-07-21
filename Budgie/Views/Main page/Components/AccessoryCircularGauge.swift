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

/// The "accessoryCircular" gauge scaffold shared by the main page's ring-based stats (budget, water,
/// weight): a blank min/max label, the accessoryCircular style, and the 1.5x scale + easeInOut
/// animation on `value` every caller otherwise repeated identically (in a couple of different, visibly
/// inconsistent orders relative to their own padding). Callers still apply their own padding, overlay
/// and accessibility modifiers to the result, exactly as they did around the raw `Gauge` before.
struct AccessoryCircularGauge<CurrentValueLabel: View>: View {
    var value: Double
    var range: ClosedRange<Double>
    var gradient: Gradient
    @ViewBuilder var currentValueLabel: () -> CurrentValueLabel

    var body: some View {
        Gauge(value: value, in: range) {
        } currentValueLabel: {
            currentValueLabel()
        } minimumValueLabel: {
            Text("")
        } maximumValueLabel: {
            Text("")
        }
        .gaugeStyle(.accessoryCircular)
        .tint(gradient)
        .scaleEffect(1.5)
        .animation(.easeInOut, value: value)
    }
}

/// A bold headline paired with a status colour — the small "**label**" readout repeated by every
/// main-page status line (the gauge's standing, the weight trend/performance labels).
struct StatusHeadline: View {
    var text: String
    var color: Color

    var body: some View {
        Text("**\(text)**").foregroundColor(color)
    }
}

/// A section header row: optional leading icon, left label, and a right-aligned label — both
/// secondary, uppercased and subheadline — shared by the main page's food and data breakdown lists.
struct SectionHeaderRow: View {
    var imageName: String?
    var leftText: String
    var rightText: String

    var body: some View {
        HStack {
            HStack {
                if let imageName {
                    Image(systemName: imageName)
                        .frame(minWidth: 30)
                        .foregroundStyle(.secondary)
                }
                Text(leftText.uppercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(rightText.uppercased())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// A thin centered divider capped to `maxWidth` — shared by the main page's row-list sections.
struct CenteredDivider: View {
    var maxWidth: CGFloat

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Divider().frame(maxWidth: maxWidth)
            }
        }
    }
}
