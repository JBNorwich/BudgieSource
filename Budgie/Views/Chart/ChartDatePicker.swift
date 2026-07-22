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

func visualDateForChart(date: Date) -> Date
{
    return getMidnightOnDayBefore(date: date)
}

func unrollPickerDate(date: Date) -> Date
{
    return getMidnightOnDayAfter(date: date)
}

private let pickerDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
}()

func formatDateForPicker(date: Date) -> String {
    pickerDateFormatter.string(from: date)
}

/// One step backward for a date window, preserving its width — the exact math behind
/// `ChartDatePicker`'s left arrow, exposed so a chart's own swipe-to-page gesture can page
/// identically to tapping the arrow.
func steppedDateRangeBackward(start: Date, end: Date, stepComponent: Calendar.Component, stepValue: Int) -> (start: Date, end: Date) {
    let cal = Calendar.current
    func stepped(_ date: Date) -> Date {
        cal.startOfDay(for: cal.date(byAdding: stepComponent, value: -stepValue, to: date) ?? date)
    }
    return (stepped(start), stepped(end))
}

/// One step forward, clamped so `end` never exceeds "tomorrow at midnight" — the exact math behind
/// `ChartDatePicker`'s right arrow. `start` is derived from the (possibly-clamped) new `end` rather
/// than stepped independently, so the window's width doesn't silently shrink right at the live edge.
func steppedDateRangeForward(start: Date, end: Date, stepComponent: Calendar.Component, stepValue: Int) -> (start: Date, end: Date) {
    let cal = Calendar.current
    func stepped(_ date: Date, by multiplier: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: stepComponent, value: stepValue * multiplier, to: date) ?? date)
    }
    let newEnd = min(stepped(end, by: 1), getMidnightOnDayAfter(date: Date()))
    let newStart = stepped(newEnd, by: -1)
    return (newStart, newEnd)
}

/// A horizontal-swipe gesture that pages a date window backward/forward, using the same stepping
/// math as `ChartDatePicker`'s arrows — shared by every chart page that embeds one, so a swipe on
/// the chart itself behaves identically to tapping the picker's own arrows.
///
/// Attached as a plain `.gesture()` (not `.highPriorityGesture`) on a chart, so the chart's own
/// press-and-hold popup gesture — nested inside via `.chartOverlay`, hence a descendant view — keeps
/// first refusal on any touch, per SwiftUI's default gesture-resolution order; a quick swipe
/// naturally fails the popup's hold requirement and falls through to this one instead.
func pagingSwipeGesture(startDate: Binding<Date>, endDate: Binding<Date>, stepComponent: Calendar.Component, stepValue: Int) -> some Gesture {
    DragGesture(minimumDistance: 40)
        .onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            let next = value.translation.width < 0
                ? steppedDateRangeForward(start: startDate.wrappedValue, end: endDate.wrappedValue, stepComponent: stepComponent, stepValue: stepValue)
                : steppedDateRangeBackward(start: startDate.wrappedValue, end: endDate.wrappedValue, stepComponent: stepComponent, stepValue: stepValue)
            startDate.wrappedValue = next.start
            endDate.wrappedValue = next.end
        }
}

struct ChartDatePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var dateChanged: Bool
    
    /// The unit each arrow steps by — and therefore the width the window keeps as you page.
    /// Defaults to a week for the ChartPage, which is this picker's primary function.
    var stepComponent: Calendar.Component = .day
    var stepValue: Int = 7
    
    @State var calsSheetSize = PresentationDetent.medium
    @State var showingFullPicker: Bool = false
    
    var atMax: Bool { endDate >= getMidnightOnDayAfter(date: Date()) }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.regularMaterial)
            .frame(maxHeight: 50)
            .overlay {
                HStack {
                    Button("", systemImage: "arrow.left") {
                        (startDate, endDate) = steppedDateRangeBackward(start: startDate, end: endDate, stepComponent: stepComponent, stepValue: stepValue)
                        dateChanged = true
                    }
                    .padding()
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray)
                        .opacity(0.25)
                        .frame(maxHeight: 40)
                        .overlay {
                            HStack {
                                Text(formatDateForPicker(date: visualDateForChart(date: getMidnightOnDayAfter(date: startDate))) + " - " + formatDateForPicker(date: getMidnightOnDayBefore(date: endDate)))
                                    .foregroundStyle(.link)
                                    .minimumScaleFactor(0.1)
                                    .scaledToFill()
                                    .padding()
                            }
                    }.onTapGesture {
                        showingFullPicker = true
                    }
                    
                    
                    Spacer()
                    
                    Button("", systemImage: "arrow.right") {
                        (startDate, endDate) = steppedDateRangeForward(start: startDate, end: endDate, stepComponent: stepComponent, stepValue: stepValue)
                        dateChanged = true
                    }
                    .padding()
                    .disabled(atMax)
                }
            }
        
            .sheet(isPresented: $showingFullPicker){
                NavigationStack {
                    FullDatePicker(displayedStartDate: visualDateForChart(date: getMidnightOnDayAfter(date: startDate)), displayedEndDate: visualDateForChart(date: endDate), showing: $showingFullPicker, endDate: $endDate, startDate: $startDate, dateChanged: $dateChanged)
                }.presentationDetents([.height(175)], selection: $calsSheetSize)
            }
    }
}

struct FullDatePicker: View {
    @State var displayedStartDate: Date
    @State var displayedEndDate: Date
    @State var origStart: Date = Date()
    @State var origEnd: Date = Date()
    @Binding var showing: Bool
    @Binding var endDate: Date
    @Binding var startDate: Date
    @Binding var dateChanged: Bool
    
    var body: some View {
        VStack {
            VStack {
                DatePicker(selection: $displayedStartDate,
                           in: ...displayedEndDate,
                           displayedComponents: .date,
                           label: {
                    Text("Start date")
                })
                
                DatePicker(selection: $displayedEndDate,
                           in: displayedStartDate...visualDateForChart(date: getMidnightOnDayAfter(date: Date())),
                           displayedComponents: .date,
                           label: {
                    Text("End date")
                })
            }
            .padding()
            HStack {
                Button("Cancel") {
                    dateChanged = false
                    showing = false
                }.buttonStyle(.bordered)
                Spacer()
                Button("OK") {
                    if (displayedStartDate != origStart || displayedEndDate != origEnd) {
                        startDate = displayedStartDate
                        endDate = unrollPickerDate(date: displayedEndDate)
                        showing = false
                        dateChanged = true
                    } else {
                        showing = false
                    }
                }.buttonStyle(.borderedProminent)
            }.padding()
        }.frame(maxHeight: 200)
        
        .onAppear(){
            origStart = displayedStartDate
            origEnd = displayedEndDate
        }
    }
}


#Preview {
    struct Preview: View {
        @State var start = getWeekBeforeDate(date: Date())
        @State var end = getMidnightOnDayAfter(date: Date())
        @State var changed: Bool = false

        var body: some View {
            ChartDatePicker(startDate: $start, endDate: $end, dateChanged: $changed)
        }
    }
    
    return Preview()
}
