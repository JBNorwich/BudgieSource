//
//  FoodHub.swift
//  Budgie
//
//  Created by Joe Baldwin on 25/08/2024.
//

import SwiftUI
import SwiftData

struct FoodHub: View {
    @Binding var dataObject: HealthData
    @Binding var todayLump: TodayLump
    
    @State var displayedData: [CalorieEntry] = []
    @State var healthKitData: [CalorieEntry] = []
    @State var curDate: Date
    @State var dateChanged: Bool = false
    @State var firstInit: Bool = true
    @State var sumCals: Int = 0
    @State var dataLump: ChartDataLump = ChartDataLump()
    @State var timeToAddOn: Date = Date()
    
    @State var addSheetDisplayed: Bool = false
    
    @State var loadingDone: Bool = false
    
    var body: some View {
        VStack {
            FoodDatePicker(curDate: $curDate, dateChanged: $dateChanged)
            SummaryRow(dataLump: dataLump)
                .frame(maxHeight: 60)
            FoodList(dataObject: $dataObject, displayedData: $displayedData, healthKitData: $healthKitData)
        }
        .padding()
        .navigationTitle("Food")
        
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Add eaten calories", systemImage: "plus") {
                    timeToAddOn = getCurrentTimeonDate(date: curDate)
                    print("Will add calories at: " + timeToAddOn.formatted())
                    addSheetDisplayed = true
                }
            }
        }
        
        .onAppear() {
            curDate = getStartOfDay(date: curDate)
            timeToAddOn = getCurrentTimeonDate(date: curDate)
            let hkCalorieObj = CalorieEntry(date:curDate, calories: 0, narrative: "Calories from Health", mealUUID: UUID(), isInHK: true, healthKitUUID: nil)
            hkCalorieObj.realEntry = false
            healthKitData.append(hkCalorieObj)
        }
        
        .onChange(of: dateChanged, initial: true) {
            Task {
                loadingDone = false
                
                let newData = await dataObject.getCalorieEntries(date: curDate)
                var budgieCalsOnDate: Int = 0
                for entry in newData {
                    budgieCalsOnDate += entry.calories
                }
                let hkEaten = await dataObject.pullCalorieTotalForDate(date: curDate, type: eatenQuantityType, hkOnly: true)
                let newActive = await dataObject.pullCalorieTotalForDate(date: curDate, type: activeQuantityType, hkOnly: false)
                let newBasal = await dataObject.pullCalorieTotalForDate(date: curDate, type: basalQuantityType, hkOnly: false)
                let newLump = ChartDataLump()
                newLump.eatenCals = hkEaten + budgieCalsOnDate
                newLump.activeCals = newActive
                newLump.basalCals = newBasal
                newLump.date = curDate
                
                displayedData = newData
                dataLump = newLump
                healthKitData[0].calories = hkEaten
                healthKitData[0].date = curDate
                timeToAddOn = getCurrentTimeonDate(date: curDate)
                loadingDone = true
                dateChanged = false
            }
        }
        
        .sheet(isPresented: $addSheetDisplayed) {
            AddCalsSheet(dataStore: $dataObject, isDisplayed: $addSheetDisplayed, curEaten: todayLump.eatenCalories, remBudg: todayLump.totalBudgetRem, selectedDate: timeToAddOn)
                .onDisappear() {
                    Task {
                        loadingDone = false
                        
                        let newData = await dataObject.getCalorieEntries(date: curDate)
                        var budgieCalsOnDate: Int = 0
                        for entry in newData {
                            budgieCalsOnDate += entry.calories
                        }
                        let hkEaten = await dataObject.pullCalorieTotalForDate(date: curDate, type: eatenQuantityType, hkOnly: true)
                        let newActive = await dataObject.pullCalorieTotalForDate(date: curDate, type: activeQuantityType, hkOnly: false)
                        let newBasal = await dataObject.pullCalorieTotalForDate(date: curDate, type: basalQuantityType, hkOnly: false)
                        let newLump = ChartDataLump()
                        newLump.eatenCals = hkEaten + budgieCalsOnDate
                        newLump.activeCals = newActive
                        newLump.basalCals = newBasal
                        newLump.date = curDate
                        
                        displayedData = newData
                        dataLump = newLump
                        healthKitData[0].calories = hkEaten
                        healthKitData[0].date = curDate
                        timeToAddOn = getCurrentTimeonDate(date: curDate)
                        
                        loadingDone = true
                        dateChanged = false
                    }
            }
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
        @State var object = HealthData()
        
        var body: some View {
            FoodHub(dataObject: $object, todayLump: $dummyData, curDate: Date())
        }
    }
    
    return Preview()
}
