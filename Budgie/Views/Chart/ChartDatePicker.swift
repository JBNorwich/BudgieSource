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

func formatDateForPicker(date: Date) -> String {
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .none
    
    return dateFormatter.string(from: date)
}

struct ChartDatePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var dateChanged: Bool
    @State var calsSheetSize = PresentationDetent.medium
    
    @State var atMax: Bool = false
    @State var showingFullPicker: Bool = false
    @State var prevStartDate: Date = Date()
    @State var nextStartDate: Date = Date()
    @State var prevEndDate: Date = Date()
    @State var nextEndDate: Date = Date()
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.regularMaterial)
            .frame(maxHeight: 50)
            .overlay {
                HStack {
                    Button("", systemImage: "arrow.left") {
                        startDate = prevStartDate // start date becomes 17/8 00:00
                        endDate = prevEndDate // end date becomes 24/8 00:00
                        prevStartDate = getWeekBeforeDate(date: startDate) // prev button moves start date to 17/8 00:00
                        prevEndDate = getWeekBeforeDate(date: endDate) //prev button moves end date to 24/8 00:00
                        nextStartDate = getWeekAfterDate(date: startDate) //next button moves start date to 24/8 00:00
                        if getWeekAfterDate(date: endDate) > getMidnightOnDayAfter(date: Date()) { // if proposed end date is after today
                            nextEndDate = getMidnightOnDayAfter(date: Date())   // set it to today
                            atMax = true
                        } else {                                                // if the end date is not after today
                            nextEndDate = getWeekAfterDate(date: endDate)       // we can use the week after the end date
                        }
                        atMax = false
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
                        endDate = nextEndDate
                        startDate = nextStartDate
                        prevStartDate = getWeekBeforeDate(date: startDate)
                        prevEndDate = getWeekBeforeDate(date: endDate)
                        if getWeekAfterDate(date: endDate) < getMidnightOnDayAfter(date: Date()) {
                            nextEndDate = getWeekAfterDate(date: endDate)
                        } else {
                            nextEndDate = getMidnightOnDayAfter(date: Date())
                        }
                        nextStartDate = getWeekBeforeDate(date: nextEndDate)
                        if endDate >= getMidnightOnDayAfter(date: Date()) {
                            endDate = getMidnightOnDayAfter(date: Date())
                            atMax = true
                        } else {
                            atMax = false
                        }
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
        
            .onAppear() {
                prevStartDate = getWeekBeforeDate(date: startDate)
                prevEndDate = getWeekBeforeDate(date: endDate)
                nextStartDate = getWeekAfterDate(date: startDate)
                nextEndDate = getWeekAfterDate(date: endDate)
                if isAfterToday(date: nextEndDate) {
                    atMax = true
                }
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
