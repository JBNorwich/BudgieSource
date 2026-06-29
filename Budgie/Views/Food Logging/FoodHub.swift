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
import SwiftData

struct FoodHub: View {
    @State private var searchTerm = ""
    
    @EnvironmentObject var todayLump: TodayLump
    
    @State var budgieData: [CalorieEntry] = []
    @State var healthKitData: [CalorieEntry] = []
    @State var mealList: [Meal] = []
    
    @State var curDate: Date
    @State var dateChanged: Bool = false
    @State var firstInit: Bool = true
    @State var sumCals: Int = 0
    @State var dataLump: ChartDataLump = ChartDataLump()
    @State var timeToAddOn: Date = Date()
    
    @State var hkCalories = 0
    
    @State var editingDone: Bool = false
    @State var addSheetDisplayed: Bool = false
    @State var toEdit: [CalorieEntry] = []
    
    @State var loadingDone: Bool = false
    
    func doUpdates() async {
        timeToAddOn = getCurrentTimeonDate(date: curDate)
        Task {
            loadingDone = false
            
            let newData = await dataStore.calorieActor.fetchCalsBetween(from: curDate, to: getMidnightOnDayAfter(date: curDate))
            var budgieCalsOnDate: Int = 0
            for entry in newData {
                budgieCalsOnDate += entry.calories
            }
            let hkEaten = await dataStore.pullCalorieTotalForDate(date: curDate, type: eatenQuantityType, hkOnly: true)
            let newActive = await dataStore.pullCalorieTotalForDate(date: curDate, type: activeQuantityType, hkOnly: false)
            let newBasal = await dataStore.pullCalorieTotalForDate(date: curDate, type: basalQuantityType, hkOnly: false)
            let newLump = ChartDataLump()
            newLump.eatenCals = hkEaten + budgieCalsOnDate
            newLump.activeCals = newActive
            newLump.basalCals = newBasal
            newLump.date = curDate
            
            mealList = await dataStore.calorieActor.cleansedMealList(data: newData)
            budgieData = newData
            budgieData.sort(by: {$0.date < $1.date})
            hkCalories = hkEaten
            dataLump = newLump
            
            timeToAddOn = getCurrentTimeonDate(date: curDate)
            loadingDone = true
            dateChanged = false
        }
    }
    
    var body: some View {
        VStack {
            VStack {
                FoodDatePicker(curDate: $curDate, dateChanged: $dateChanged)
                SummaryRow(dataLump: dataLump, curDate: $curDate)
                    .frame(maxHeight: 60)
            }
            .padding()
            List {
                if budgieData.count != 0 {
                    ForEach(mealList, id: \.self) { meal in
                        Section(header: Text(meal.name)) {
                            ForEach(budgieData, id: \.self) { entry in
                                if entry.meal == meal.mealUUID {
                                    NavigationLink(destination: EditCalsSheet(entryToEdit: entry)
                                            .environmentObject(todayLump)
                                            .onDisappear {
                                                Task {
                                                    await doUpdates()
                                                }
                                            }
                                    ) {
                                        CalorieEntryView(calories: entry.calories, narrative: entry.narrative ?? "Quick calories", realEntry: entry.realEntry, date: entry.date)
                                            .contentShape(Rectangle())
                                    }
                                }
                            }.onDelete(perform: delete)
                        }
                    }
                } else {
                    Text("You have no calories logged in Budgie Diet on this day.")
                }
                
                if hkCalories != 0  {
                    Section(header: Text("Calories from other apps"), footer: Text("These are calories logged in Health by other apps. You'll need to go to the app that logged them to change or delete them.")) {
                        CalorieEntryView(calories: hkCalories, narrative: "Calories from other apps", realEntry: false, date: curDate)
                            .deleteDisabled(true)
                    }
                }
            }.listStyle(.grouped)
        }
        .navigationTitle("Food")
        
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Add eaten calories", systemImage: "plus") {
                    timeToAddOn = getCurrentTimeonDate(date: curDate)
                    addSheetDisplayed = true
                }
            }
        }
        
        .onAppear() {
            curDate = getStartOfDay(date: curDate)
        }
        
        .onChange(of: dateChanged, initial: true) {
            Task {
                await doUpdates()
            }
        }
        
        .onChange(of: sumCals, initial: false) {
            Task {
                await doUpdates()
            }
        }
              
        .sheet(isPresented: $addSheetDisplayed) {
            AddCalsSheet(isDisplayed: $addSheetDisplayed, selectedDate: timeToAddOn).environmentObject(todayLump)
                .onDisappear() {
                    Task {
                        await doUpdates()
                    }
                }
        }
    }
    
    func delete(at offsets: IndexSet) {
        var toBin: [CalorieEntry] = []
        for itemId in offsets {
            toBin.append(budgieData[itemId])
        }
        budgieData.remove(atOffsets: offsets)
        Task {
            await dataStore.calorieActor.deleteEntries(objects: toBin)
            await doUpdates()
        }
    }
}


struct CalorieEntryView: View {
    var calories: Int
    var narrative: String
    var realEntry: Bool
    var date: Date
    
    var body: some View {
        HStack {
            if realEntry != false {
                Text(date.formatted(date: .omitted, time:.shortened))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 50)
                    .multilineTextAlignment(.leading)
            }
            Text(narrative)
            Spacer()
            Text(calories.formatted())
                .contentTransition(.numericText())
        }
    }
}

#Preview {
    struct Preview: View {
        @State var dummyData = TodayLump()
        
        var body: some View {
            FoodHub(curDate: Date()).environmentObject(dummyData)
        }
    }
    
    return Preview()
}
