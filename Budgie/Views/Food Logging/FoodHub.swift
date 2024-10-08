//
//  FoodHub.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 25/08/2024.
//

import SwiftUI
import SwiftData

struct FoodHub: View {
    @State private var searchTerm = ""
    
    @Binding var dataObject: HealthData
    @Binding var todayLump: TodayLump
    
    @State var budgieData: [CalorieEntry] = []
    @State var healthKitData: [CalorieEntry] = []
    @State var mealList: [Meal] = []
    
    //@StateObject var listObject = ListObject()
    
    @State var curDate: Date
    @State var dateChanged: Bool = false
    @State var firstInit: Bool = true
    @State var sumCals: Int = 0
    @State var dataLump: ChartDataLump = ChartDataLump()
    @State var timeToAddOn: Date = Date()
    
    @State var hkCalories = 0
    
    @State var addSheetDisplayed: Bool = false
    
    @State var loadingDone: Bool = false
    
    func doUpdates() async{
        timeToAddOn = getCurrentTimeonDate(date: curDate)
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
            
            mealList = dataObject.calorieModel.cleansedMealList(data: newData)
            budgieData = newData
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
//            FoodList(dataObject: $dataObject, list: listObject)
            List {
                if budgieData.count != 0 {
                    ForEach(mealList, id: \.self) { meal in
                        Section(header: Text(meal.name)) {
                            ForEach(budgieData, id: \.self) { entry in
                                if entry.meal == meal.mealUUID {
                                    CalorieEntryView(calories: entry.calories, narrative: entry.narrative ?? "Quick calories", realEntry: entry.realEntry, date: entry.date)
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
            AddCalsSheet(dataStore: $dataObject, isDisplayed: $addSheetDisplayed, curEaten: todayLump.eatenCalories, remBudg: todayLump.totalBudgetRem, selectedDate: timeToAddOn)
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
            await dataObject.deleteCalorieEntries(calorieObjects: toBin)
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
        @State var object = HealthData()
        
        var body: some View {
            FoodHub(dataObject: $object, todayLump: $dummyData, curDate: Date())
        }
    }
    
    return Preview()
}
