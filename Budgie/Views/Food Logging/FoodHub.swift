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
    @EnvironmentObject var todayLump: TodayLump
    
    @State var budgieData: [CalorieEntry] = []
    @State var mealList: [Meal] = []
    
    @State var curDate: Date
    @State var dateChanged: Bool = false
    @State var dataLump: ChartDataLump = ChartDataLump()
    @State var timeToAddOn: Date = Date()
    @State var hkCalories = 0
    @State var addSheetDisplayed: Bool = false
    @State var loadingDone: Bool = false
    
    init(curDate: Date) {
        // Normalise to midnight up front, so the first fetch is already day-aligned.
        _curDate = State(initialValue: getStartOfDay(date: curDate))
    }
    
    var groupedByMeal: [UUID: [CalorieEntry]] {
        Dictionary(grouping: budgieData, by: \.meal)
    }
    
    func doUpdates() async {
        loadingDone = false
        
        let newData = await dataStore.calorieActor.fetchCalsBetween(from: curDate, to: getMidnightOnDayAfter(date: curDate))
        let budgieCalsOnDate = newData.reduce(0) { $0 + $1.calories }
        async let hkEatenTask = dataStore.pullCalorieTotalForDate(date: curDate, type: eatenQuantityType, hkOnly: true)
        async let activeTask = dataStore.pullCalorieTotalForDate(date: curDate, type: activeQuantityType, hkOnly: false)
        async let basalTask = dataStore.pullCalorieTotalForDate(date: curDate, type: basalQuantityType, hkOnly: false)
        let (hkEaten, newActive, newBasal) = await (hkEatenTask, activeTask, basalTask)
        
        let newLump = ChartDataLump()
        newLump.eatenCals = hkEaten + budgieCalsOnDate
        newLump.activeCals = newActive
        newLump.basalCals = newBasal
        newLump.date = curDate
        
        mealList = await dataStore.calorieActor.cleansedMealList(data: newData)
        budgieData = newData.sorted { $0.date < $1.date }
        hkCalories = hkEaten
        dataLump = newLump
        
        timeToAddOn = getCurrentTimeonDate(date: curDate)
        loadingDone = true
        dateChanged = false
    }
    
    var body: some View {
        VStack {
            VStack {
                FoodDatePicker(curDate: $curDate, dateChanged: $dateChanged)
                ChartTableRow(dataLump: dataLump)
            }
            .padding()
            List {
                if !budgieData.isEmpty {
                    ForEach(mealList) { meal in
                        let entries = groupedByMeal[meal.mealUUID] ?? []
                        if !entries.isEmpty {
                            Section(header: Text(meal.name)) {
                                ForEach(entries) { entry in
                                    NavigationLink(destination: EditCalsSheet(entryToEdit: entry)
                                            .environmentObject(todayLump)
                                            .onDisappear { Task { await doUpdates() } }
                                    ) {
                                        CalorieEntryView(calories: entry.calories,
                                                         narrative: entry.narrative ?? "Quick calories",
                                                         manufacturer: entry.manufacturer,
                                                         protein: entry.protein,
                                                         carbs: entry.carbs,
                                                         fat: entry.fat,
                                                         detailed: true)
                                    }
                                }
                                .onDelete { offsets in delete(offsets, from: entries) }
                            }
                        }
                    }
                } else {
                    Text("You have no calories logged in Budgie Diet on this day.")
                }
                
                if hkCalories != 0  {
                    Section(header: Text("Calories from other apps"), footer: Text("These are calories logged in Health by other apps. You'll need to go to the app that logged them to change or delete them.")) {
                        CalorieEntryView(calories: hkCalories, narrative: "Calories from other apps")
                            .deleteDisabled(true)
                    }
                }
            }.listStyle(.grouped)
        }
        .navigationTitle("Food")
        
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    FoodLibraryView()
                } label: {
                    Label("Your foods", systemImage: "carrot")
                }
                Button("Add eaten calories", systemImage: "plus") {
                    timeToAddOn = getCurrentTimeonDate(date: curDate)
                    addSheetDisplayed = true
                }
            }
        }
        
        .task {
            await doUpdates()
        }

        .onChange(of: dateChanged) {
            // doUpdates() resets dateChanged to false when it finishes; only react to
            // the true transition so each date change fetches exactly once.
            if dateChanged {
                Task { await doUpdates() }
            }
        }
              
        .sheet(isPresented: $addSheetDisplayed) {
            NavigationStack {
                AddCalsSheet(selectedDate: timeToAddOn).environmentObject(todayLump)
            }
            .onDisappear {
                Task {
                    await doUpdates()
                }
            }
        }
    }
    
    func delete(_ offsets: IndexSet, from entries: [CalorieEntry]) {
        let toBin = offsets.map { entries[$0] }
        budgieData.removeAll { toBin.contains($0) }
        Task {
            await dataStore.calorieActor.deleteEntries(objects: toBin)
            await doUpdates()
            await dataStore.updateLump(todayLump: todayLump)
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
