//
//  ChartDatePicker.swift
//  Budgie
//
//  Created by Joe Baldwin on 24/08/2024.
//

import SwiftUI

struct FoodDatePicker: View {
    @Binding var curDate: Date
    @Binding var dateChanged: Bool

    @State var atMax: Bool = false
    @State var prevDate: Date = Date()
    @State var nextDate: Date = Date()
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.regularMaterial)
            .frame(maxHeight: 50)
            .overlay {
                HStack {
                    Button("", systemImage: "arrow.left") {
                        curDate = prevDate
                    }
                    .padding()
                    
                    HStack {
                        Spacer()
                        
                        DatePicker(selection: $curDate,
                                   in: ...Date(),
                                   displayedComponents: .date,
                                   label: { Text("Date")}).labelsHidden()
                        Spacer()
                    }
                    Button("", systemImage: "arrow.right") {
                        curDate = nextDate
                    }
                        .padding()
                        .disabled(atMax)
                }
            }
        
            .onChange(of: curDate) {
                nextDate = getMidnightOnDayAfter(date: curDate)
                prevDate = getMidnightOnDayBefore(date: curDate)
                if nextDate > getStartOfDay(date: Date()) {
                    atMax = true
                } else {
                    atMax = false
                }
                print("New date: " + curDate.formatted())
                print("New prevbutton date: " + prevDate.formatted())
                print("New nextbutton date" + nextDate.formatted())
                dateChanged = true
            }
        
            .onAppear() {
                print("Initial date: " + curDate.formatted())
                
                prevDate = getMidnightOnDayBefore(date: curDate)
                nextDate = getMidnightOnDayAfter(date: curDate)
                
                if nextDate > getStartOfDay(date: Date()) {
                    atMax = true
                } else {
                    atMax = false
                }
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
