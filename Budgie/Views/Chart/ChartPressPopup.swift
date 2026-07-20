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
import Charts

/// Adds press-and-hold-to-inspect to a chart with a date-based X axis, shared by every chart in this
/// stack. Deliberately gated behind a genuine long press (not a plain tap/drag, and not the simpler
/// `chartXSelection` API) so it doesn't compete with a swipe-to-page-the-date-range gesture on the
/// same chart — a quick swipe never satisfies the hold delay, so the two coexist without fighting
/// over the same touch.
private struct ChartPressPopupModifier<Popup: View>: ViewModifier {
    var dates: [Date]
    @ViewBuilder var popup: (Date) -> Popup
    @State private var selectedDate: Date?

    func body(content: Content) -> some View {
        content
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            LongPressGesture(minimumDuration: 0.35)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { value in
                                    guard case .second(true, let drag?) = value, !dates.isEmpty,
                                          let plotFrame = proxy.plotFrame else { return }
                                    let origin = geometry[plotFrame].origin
                                    let x = drag.location.x - origin.x
                                    guard let rawDate: Date = proxy.value(atX: x) else { return }
                                    selectedDate = dates.min { abs($0.timeIntervalSince(rawDate)) < abs($1.timeIntervalSince(rawDate)) }
                                }
                                .onEnded { _ in selectedDate = nil }
                        )
                }
            }
            .overlay(alignment: .top) {
                if let selectedDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedDate.formatted(date: .abbreviated, time: .omitted)).font(.caption).bold()
                        popup(selectedDate)
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 2)
                    .padding(.top, 6)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: selectedDate)
                }
            }
    }
}

extension View {
    /// Press-and-hold on a date-axis chart: after a brief hold, shows a small floating card above
    /// the chart for whichever entry in `dates` is nearest the touch — a bold date header (added
    /// here, so every chart's popup shares one header instead of repeating it) followed by `content`,
    /// tracking the finger until released. `dates` should be the exact day-start dates the chart's
    /// marks use.
    func chartPressPopup<Content: View>(dates: [Date], @ViewBuilder content: @escaping (Date) -> Content) -> some View {
        modifier(ChartPressPopupModifier(dates: dates, popup: content))
    }
}
