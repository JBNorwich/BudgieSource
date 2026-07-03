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

struct FoodDatePicker: View {
    @Binding var curDate: Date
    @Binding var dateChanged: Bool
    @State var prevDate: Date = Date()
    @State var nextDate: Date = Date()
    
    private var atToday: Bool {
        getStartOfDay(date: curDate) >= getStartOfDay(date: Date())
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.regularMaterial)
            .frame(maxHeight: 50)
            .overlay {
                HStack {
                    Button("Previous day", systemImage: "arrow.left") {
                        curDate = prevDate
                    }
                        .labelStyle(.iconOnly)
                        .padding()
                    
                    HStack {
                        Spacer()
                        
                        DatePicker(selection: $curDate,
                            in: ...Date(),
                            displayedComponents: .date,
                            label: { Text("Date")}).labelsHidden()
                        Spacer()
                    }
                    Button("Next day", systemImage: "arrow.right") {
                        curDate = nextDate
                    }
                        .labelStyle(.iconOnly)
                        .padding()
                        .disabled(atToday)
                }
            }
        
            .onChange(of: curDate) {
                nextDate = getMidnightOnDayAfter(date: curDate)
                prevDate = getMidnightOnDayBefore(date: curDate)
                dateChanged = true
            }
        
            .onAppear() {                
                prevDate = getMidnightOnDayBefore(date: curDate)
                nextDate = getMidnightOnDayAfter(date: curDate)
            }
    }
}

//
#Preview {
    struct Preview: View {
        @State var start = getWeekBeforeDate(date: Date())
        @State var end = getMidnightOnDayAfter(date: Date())
        @State var changed: Bool = false

        var body: some View {
            FoodDatePicker(curDate: $end, dateChanged: $changed)
        }
    }
    
    return Preview()
}
