//
//  ChartData.swift
//  Budgie
//
//  Created by Joe Baldwin on 23/08/2024.
//

import Foundation
import HealthKitUI

class ChartDataLump: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var eatenCals: Int = 0
    var activeCals: Int = 0
    var basalCals: Int = 0
    var totalCals: Int {
        get { return activeCals + basalCals }
    }
    var deficit: Int {
        // if calorie deficit, pops positive. if surplus, pops negative
        get { return totalCals - eatenCals }
    }
}

@MainActor class ChartData: ObservableObject {
    static let shared = ChartData()
    
    @Published var returnedChartData: [ChartDataLump] = []
    var activePackets: [CalsPacket] = []
    var basalPackets: [CalsPacket] = []
    var eatenPackets: [CalsPacket] = []
    var budgieEatenPackets: [CalsPacket] = []
    var startDate: Date = Date()
    var endDate: Date = Date()
    var activeDone: Bool = false
    var basalDone: Bool = false
    var eatenDone: Bool = false
    @Published var dataUpdated: Bool = false
    
    init() {
        endDate = getMidnightOnDayAfter(date: Date())
        startDate = getWeekBeforeDate(date: endDate)
        Task {
            await self.pokeForUpdate()
        }
    }
    
    func allDoneCheck() -> Bool {
        if activeDone == true && basalDone == true && eatenDone == true
        {
            return true
        } else {
            return false
        }
    }
    
    @MainActor func cleanDataObject() {
        self.basalPackets.removeAll()
        self.activePackets.removeAll()
        self.eatenPackets.removeAll()
        self.budgieEatenPackets.removeAll()
    }
    
    @MainActor func pokeForUpdate() async
    {
        self.cleanDataObject()
        print ("Poked for update")
        if settingsObj.manualMode == false {
            await fetchChartActive()
            await fetchChartBasal()
        } else {
            self.activeDone = true
            self.basalDone = true
        }
        await fetchChartEaten()
        var notified: Bool = false
        while allDoneCheck() != true {
            if notified == false { print ("Checking to see if updated..."); notified = true }
        }
        print("Update done!")
        self.dataUpdated = true
    }
    
    @MainActor func fetchChartActive() async
    {
        let actCalsType = HKQuantityType(.activeEnergyBurned)
        let everyDay = DateComponents(day:1)
        let queryPeriod = HKQuery.predicateForSamples(withStart: self.startDate, end: self.endDate, options:.strictStartDate)
        let actCalsQuery = HKStatisticsCollectionQuery(quantityType: actCalsType, quantitySamplePredicate: queryPeriod, options: .cumulativeSum, anchorDate: self.startDate, intervalComponents: everyDay)
        
        // query active calories, digest into packets
        actCalsQuery.initialResultsHandler = {
            query, results, error in
            
            self.activePackets.removeAll()
            
            if let error = error as? HKError {
                switch (error.code) {
                case .errorDatabaseInaccessible:
                    // HealthKit couldn't access the database because the device is locked.
                    return
                default:
                    // Handle other HealthKit errors here.
                    return
                }
            }
            
            guard let actCollection = results else {
                assertionFailure("")
                return
            }
            
            actCollection.enumerateStatistics(from: self.startDate, to: self.endDate)
            { statistics, _ in
                if let quantity = statistics.sumQuantity() {
                    let date = statistics.startDate
                    let value = Int(quantity.doubleValue(for: .kilocalorie()))
                    
                    self.activePackets.append(CalsPacket(date:date, cals:value))
                }
            }
            self.activeDone = true
        }
        healthStore.execute(actCalsQuery)
    }
    
    @MainActor func fetchChartBasal() async
    {
        let basalCalsType = HKQuantityType(.basalEnergyBurned)
        let everyDay = DateComponents(day:1)
        let queryPeriod = HKQuery.predicateForSamples(withStart: self.startDate, end: self.endDate, options:.strictStartDate)
        let actCalsQuery = HKStatisticsCollectionQuery(quantityType: basalCalsType, quantitySamplePredicate: queryPeriod, options: .cumulativeSum, anchorDate: self.startDate, intervalComponents: everyDay)
        
        // query active calories, digest into packets
        actCalsQuery.initialResultsHandler = {
            query, results, error in
            
            if let error = error as? HKError {
                switch (error.code) {
                case .errorDatabaseInaccessible:
                    // HealthKit couldn't access the database because the device is locked.
                    return
                default:
                    // Handle other HealthKit errors here.
                    return
                }
            }
            
            guard let actCollection = results else {
                assertionFailure("")
                return
            }
            
            actCollection.enumerateStatistics(from: self.startDate, to: self.endDate)
            { statistics, _ in
                if let quantity = statistics.sumQuantity(){
                    let date = statistics.startDate
                    let value = Int(quantity.doubleValue(for: .kilocalorie()))
                    self.basalPackets.append(CalsPacket(date:date, cals:value))
                }
            }
            
            self.basalDone = true
            print ("Basal cals updated")
        }
        
        healthStore.execute(actCalsQuery)
    }
    
    @MainActor func fetchChartEaten() async
    {
        if settingsObj.manualMode == false {
            let eatenCalsType = HKQuantityType(.dietaryEnergyConsumed)
            let everyDay = DateComponents(day:1)
            let queryPeriod = HKQuery.predicateForSamples(withStart: self.startDate, end: self.endDate, options:.strictStartDate)
            let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,queryPeriod])
            let actCalsQuery = HKStatisticsCollectionQuery(quantityType: eatenCalsType, quantitySamplePredicate: queryPredicate, options: .cumulativeSum, anchorDate: self.startDate, intervalComponents: everyDay)
            
            // query active calories, digest into packets
            actCalsQuery.initialResultsHandler = {
                query, results, error in
                
                if let error = error as? HKError {
                    switch (error.code) {
                    case .errorDatabaseInaccessible:
                        // HealthKit couldn't access the database because the device is locked.
                        return
                    default:
                        // Handle other HealthKit errors here.
                        return
                    }
                }
                
                guard let actCollection = results else {
                    assertionFailure("")
                    return
                }
                
                actCollection.enumerateStatistics(from: self.startDate, to: self.endDate)
                { statistics, _ in
                    if let quantity = statistics.sumQuantity(){
                        let date = statistics.startDate
                        
                        let value = Int(quantity.doubleValue(for: .kilocalorie()))
                        
                        self.eatenPackets.append(CalsPacket(date:date, cals:value))
                    }
                }
            }
            
            healthStore.execute(actCalsQuery)
        }
        
        let model = CalorieData()
        let objArray = model.fetchCalsBetween(from: self.startDate, to: self.endDate)
        for object in objArray {
            print (object.date.formatted() + " " + object.calories.formatted())
            self.budgieEatenPackets.append(CalsPacket(date:getStartOfDay(date: object.date), cals:object.calories))
        }
        self.eatenDone = true
    }
        
    @MainActor func assembleChartData()
    {
        print("Assembly requested...")
        var returnValue: [ChartDataLump] = []
        
        if settingsObj.manualMode == true {
            var iterateDate = self.startDate
            while iterateDate < getMidnightOnDayAfter(date: self.endDate) {
                let newLump = ChartDataLump()
                newLump.date = iterateDate
                newLump.basalCals = settingsObj.manualBMR
                newLump.activeCals = settingsObj.manualActive
                returnValue.append(newLump)
                iterateDate = getMidnightOnDayAfter(date: iterateDate)
            }
        } else {
            for basalStruct in basalPackets {
                if basalStruct.date < self.endDate {
                    let newLump = ChartDataLump()
                    newLump.date = basalStruct.date
                    newLump.basalCals = basalStruct.cals
                    returnValue.append(newLump)
                }
            }
            
            for activeStruct in activePackets {
                let packetDate = activeStruct.date
                for lump in returnValue {
                    if lump.date == packetDate {
                        lump.activeCals = activeStruct.cals
                        //lump.totalCals = lump.activeCals + lump.basalCals
                    }
                }
            }
            
            for eatenStruct in eatenPackets {
                let packetDate = eatenStruct.date
                for lump in returnValue {
                    if lump.date == packetDate {
                        lump.eatenCals = eatenStruct.cals
                    }
                }
            }
        }
        
        for budgieStruct in budgieEatenPackets {
            let packetDate = budgieStruct.date
            for lump in returnValue {
                print ("Lump date: " + lump.date.formatted())
                print ("Packet date: " + packetDate.formatted())
                if lump.date == packetDate {
                    lump.eatenCals = lump.eatenCals + budgieStruct.cals
                }
            }
        }
        
        self.activeDone = false
        self.basalDone = false
        self.eatenDone = false
        self.dataUpdated = false
        
        self.returnedChartData = returnValue
        print ("Chart data returned")
    }
}
