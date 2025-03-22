//
//  WaterView.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 22/03/2025.
//

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
        let totalData = await dataStore.getWaterOnDate(date: curDate)
        hkQuantity = totalData.hk
        totalWater = totalData.hk + totalData.bd
        budgieData = await dataStore.waterActor.getEntriesOnDate(date: curDate)
        dateChanged = false
    }
    
    var body: some View {
        VStack {
            FoodDatePicker(curDate: $curDate, dateChanged: $dateChanged)
                .padding()
            Text("Total water: \(totalWater)ml")
                .font(.title)
            List {
                if budgieData.count != 0 {
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
                .onDisappear() {
                    Task {
                        await doUpdates()
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
        }
    }
}

struct WaterEntryView: View {
    var quantity: Int
    var date: Date
    var realEntry: Bool
    
    var body: some View {
        HStack {
            if realEntry != false {
                Text(date.formatted(date: .omitted, time:.shortened))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 50)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Total in Apple Health")
            }
            Spacer()
            Text("\(quantity.formatted())ml")
                .contentTransition(.numericText())
        }
    }
}
