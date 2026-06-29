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

struct TodayFoodList: View {
    @Environment(\.defaultMinListRowHeight) var minRowHeight
    
    @EnvironmentObject var dataLump: TodayLump
    @State var firstRow = true
    
    var body: some View {
        Spacer()
        if dataLump.foodList.count != 0 || dataLump.healthKitCalories != 0 {
            if dataLump.foodList.count != 0 {
                ForEach(dataLump.mealList) { meal in
                    HStack {
                        Text(meal.name.uppercased())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if dataLump.mealList.first == meal {
                            Text("CALORIES")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(dataLump.foodList) { entry in
                        if entry.meal == meal.mealUUID {
                            CalorieEntryView(calories: entry.calories, narrative: entry.narrative ?? "Quick calories", realEntry: entry.realEntry, date: entry.date)
                        }
                    }
                    HStack {
                        Spacer()
                        VStack {
                            Divider()
                                .frame(maxWidth: 50)
                        }
                    }
                    HStack {
                        Spacer()
                        Text("**\(dataLump.mealTotalList[meal.mealUUID]!.formatted())**")
                    }
                    Spacer()
                }
            }
            
            if dataLump.healthKitCalories != 0 {
                Spacer()
                HStack {
                    Text("FROM OTHER APPS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                        Text("CALORIES")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                }
                CalorieEntryView(calories: dataLump.healthKitCalories, narrative: "Calories from Apple Health", realEntry: false, date: getStartOfDay(date: Date()))
                Spacer()
            }
        } else {
            Text("You have no eaten calories logged today.")
        }
    }
}

//#Preview {
//    TodayFoodList()
//}
