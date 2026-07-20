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
    
    /// Shifts a date by `times` whole steps, normalised to midnight to match the app's
    /// half-open [start, midnight-after-end) date convention.
    private func stepped(_ date: Date, times: Int) -> Date {
        let cal = Calendar.current
        let shifted = cal.date(byAdding: stepComponent, value: stepValue * times, to: date) ?? date
        return cal.startOfDay(for: shifted)
    }

    var prevStartDate: Date { stepped(startDate, times: -1) }
    var prevEndDate: Date { stepped(endDate, times: -1) }
    var nextStartDate: Date { stepped(nextEndDate, times: -1) }
    var nextEndDate: Date { min(stepped(endDate, times: 1), getMidnightOnDayAfter(date: Date())) }
    var atMax: Bool { endDate >= getMidnightOnDayAfter(date: Date()) }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.regularMaterial)
            .frame(maxHeight: 50)
            .overlay {
                HStack {
                    Button("", systemImage: "arrow.left") {
                        let newStart = prevStartDate
                        let newEnd = prevEndDate
                        startDate = newStart
                        endDate = newEnd
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
                        let newStart = nextStartDate
                        let newEnd = nextEndDate
                        startDate = newStart
                        endDate = newEnd
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
