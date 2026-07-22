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

struct WaterPage: View {
    @EnvironmentObject var todayLump: TodayLump
    
    @State var curDate: Date
    @State var budgieData: [WaterEntry] = []
    
    @State var dateChanged: Bool = false
    @State var hkQuantity: Int = 0
    @State var totalWater: Int = 0
    
    @State var addSheetDisplayed: Bool = false
    @State var timeToAddOn: Date = Date()
    
    func doUpdates() async {
        timeToAddOn = getCurrentTimeonDate(date: curDate)
        async let waterTask = dataStore.getWaterOnDate(date: curDate)
        async let entriesTask = dataStore.waterActor.getEntriesOnDate(date: curDate)
        let (water, entries) = await (waterTask, entriesTask)
        hkQuantity = water.hk
        budgieData = entries
        totalWater = hkQuantity + budgieData.reduce(0) { $0 + $1.quantity }
        dateChanged = false
    }
    
    var body: some View {
        VStack {
            FoodDatePicker(curDate: $curDate, dateChanged: $dateChanged)
                .padding()
            Text("Total water: \(renderVolume(millilitres: totalWater))")
                .font(.title)
            List {
                if !budgieData.isEmpty {
                    Section(header: Text("Water logged in Budgie Diet")) {
                        ForEach(budgieData) { entry in
                            WaterEntryView(quantity: entry.quantity, date: entry.date, realEntry: true)
                        }.onDelete(perform: delete)
                    }
                } else {
                    Text("You have no water entries logged in Budgie Diet on this day.")
                }
                
                if hkQuantity != 0 {
                    Section(header: Text("Water logged in other apps"), footer: Text("This is water logged in Apple Health by other apps. You'll need to go to the app that logged them to change or delete them.")) {
                        WaterEntryView(quantity: hkQuantity, date: curDate, realEntry: false)
                    }
                }
            }.listStyle(.grouped)
        }
        .navigationTitle("Water")
        
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Add water", systemImage: "plus") {
                    timeToAddOn = getCurrentTimeonDate(date: curDate)
                    addSheetDisplayed = true
                }
            }
        }
        
        .sheet(isPresented: $addSheetDisplayed) {
            AddWaterSheet(isDisplayed: $addSheetDisplayed, dateToAddOn: timeToAddOn)
                .environmentObject(todayLump)
                .onDisappear() {
                    Task {
                        await doUpdates()
                        await dataStore.updateLump(todayLump: todayLump)
                    }
                }
        }
        
        .onChange(of: curDate, initial: false) {
            Task {
                await doUpdates()
            }
        }
        
        .onAppear() {
            Task {
                await doUpdates()
            }
        }
    }
    
    func delete(at offsets: IndexSet) {
        var toBin: [WaterEntry] = []
        for itemId in offsets {
            toBin.append(budgieData[itemId])
        }
        budgieData.remove(atOffsets: offsets)
        Task {
            await dataStore.waterActor.deleteEntries(objects: toBin)
            await doUpdates()
            await dataStore.updateLump(todayLump: todayLump)
        }
    }
}

struct WaterEntryView: View {
    var quantity: Int
    var date: Date
    var realEntry: Bool
    
    var body: some View {
        HStack {
            if realEntry {
                Text(date.formatted(date: .omitted, time:.shortened))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 50)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Total in Apple Health")
            }
            Spacer()
            Text(renderVolume(millilitres: quantity))
                .contentTransition(.numericText())
        }
    }
}
