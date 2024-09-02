//
//  FoodHub.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 25/08/2024.
//

import SwiftUI
import SwiftData

class ListObject: ObservableObject {
    var curDate: Date
    var budgieData: [CalorieEntry]
    var hkCalories: Int
    var mealList: [Meal]
    
    init() {
        budgieData = []
        mealList = []
        curDate = Date()
        hkCalories = 0
    }
}

struct FoodHub: View {
    @Binding var dataObject: HealthData
    @Binding var todayLump: TodayLump
    
    @State var displayedData: [CalorieEntry] = []
    @State var healthKitData: [CalorieEntry] = []
    @State var mealList: [Meal] = []
    
    @State var listObject = ListObject()
    
    @State var curDate: Date
    @State var dateChanged: Bool = false
    @State var firstInit: Bool = true
    @State var sumCals: Int = 0
    @State var dataLump: ChartDataLump = ChartDataLump()
    @State var timeToAddOn: Date = Date()
    
    @State var addSheetDisplayed: Bool = false
    
    @State var loadingDone: Bool = false
    
    func doUpdates() async{
        timeToAddOn = getCurrentTimeonDate(date: curDate)
        Task {
            let calorieData = await CalorieData()
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
            
            listObject.mealList = calorieData.cleansedMealList(data: newData)
            listObject.budgieData = newData
            listObject.hkCalories = hkEaten
            dataLump = newLump
            
            timeToAddOn = getCurrentTimeonDate(date: curDate)
            loadingDone = true
            dateChanged = false
        }
    }
    
    var body: some View {
        VStack {
            FoodDatePicker(curDate: $curDate, dateChanged: $dateChanged)
            SummaryRow(dataLump: dataLump, curDate: $curDate)
                .frame(maxHeight: 60)
            FoodList(dataObject: $dataObject, list: listObject)
        }
        .padding()
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
        
        .sheet(isPresented: $addSheetDisplayed) {
            AddCalsSheet(dataStore: $dataObject, isDisplayed: $addSheetDisplayed, curEaten: todayLump.eatenCalories, remBudg: todayLump.totalBudgetRem, selectedDate: timeToAddOn)
                .onDisappear() {
                    Task {
                        await doUpdates()
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
