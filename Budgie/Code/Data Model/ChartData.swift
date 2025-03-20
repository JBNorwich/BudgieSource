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

class ChartData: ObservableObject {
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
    var actAsIfManual: Bool = false
    var updateInProgress: Bool = false
    
    init() {
        endDate = getMidnightOnDayAfter(date: Date())
        startDate = getWeekBeforeDate(date: endDate)
        Task {
            await self.pokeForUpdate()
        }
    }
    
    func cleanDataObject() {
        self.basalPackets.removeAll()
        self.activePackets.removeAll()
        self.eatenPackets.removeAll()
        self.budgieEatenPackets.removeAll()
        self.actAsIfManual = false
    }
    
    func pokeForUpdate() async
    {
        if self.updateInProgress == false {
            self.updateInProgress = true
            if settingsObj.manualMode == false {
                self.activePackets = await fetchChartActive()
                self.basalPackets = await fetchChartBasal()
                self.activeDone = true
                self.basalDone = true
            } else {
                self.activeDone = true
                self.basalDone = true
            }
            let eatenPacketsReturn = await fetchChartEaten()
            self.eatenPackets = eatenPacketsReturn.hk
            self.budgieEatenPackets = eatenPacketsReturn.budgie
            self.dataUpdated = true
        }
    }
    
    func fetchChartActive() async -> [CalsPacket]
    {
        let everyDay = DateComponents(day:1)
        let queryPeriod = HKQuery.predicateForSamples(withStart: self.startDate, end: self.endDate, options:.strictEndDate)
        
        return await withCheckedContinuation { continuation in
            let actCalsQuery = HKStatisticsCollectionQuery(quantityType: activeQuantityType, quantitySamplePredicate: queryPeriod, options: .cumulativeSum, anchorDate: self.startDate, intervalComponents: everyDay)
            
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
                
                var packetsToAdd: [CalsPacket] = []
                
                actCollection.enumerateStatistics(from: self.startDate, to: self.endDate)
                { statistics, _ in
                    if let quantity = statistics.sumQuantity() {
                        let date = statistics.startDate
                        let value = Int(quantity.doubleValue(for: .kilocalorie()).rounded())
                        packetsToAdd.append(CalsPacket(date:date, cals:value))
                    }
                }
                self.activePackets.append(contentsOf: packetsToAdd)
                continuation.resume(returning: packetsToAdd)
            }
            healthStore.execute(actCalsQuery)
        }
    }
    
    func fetchChartBasal() async -> [CalsPacket]
    {
        let everyDay = DateComponents(day:1)
        let queryPeriod = HKQuery.predicateForSamples(withStart: self.startDate, end: self.endDate, options:.strictEndDate)
        
        return await withCheckedContinuation { continuation in
            let actCalsQuery = HKStatisticsCollectionQuery(quantityType: basalQuantityType, quantitySamplePredicate: queryPeriod, options: .cumulativeSum, anchorDate: self.startDate, intervalComponents: everyDay)
            // query active calories, digest into packets
            actCalsQuery.initialResultsHandler = { query, results, error in
                
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
                
                var cumValue: Int = 0
                
                var packetsToAdd: [CalsPacket] = []
                
                actCollection.enumerateStatistics(from: self.startDate, to: self.endDate)
                { statistics, _ in
                    if let quantity = statistics.sumQuantity() {
                        let date = statistics.startDate
                        let value = Int(quantity.doubleValue(for: .kilocalorie()).rounded())
                        cumValue += value
                        packetsToAdd.append(CalsPacket(date:date, cals:value))
                    }
                }
                
                if cumValue == 0 {
                    self.actAsIfManual = true
                }
                
                continuation.resume(returning: packetsToAdd)
            }
            healthStore.execute(actCalsQuery)
        }
    }
    
    func fetchChartEaten() async -> (budgie: [CalsPacket], hk: [CalsPacket])
    {
        let model = await CalorieData()
        let objArray = await model.fetchCalsBetween(from: self.startDate, to: self.endDate)
        var budgiePackets: [CalsPacket] = []
        var hkPackets: [CalsPacket] = []
        for object in objArray {
            budgiePackets.append(CalsPacket(date:getStartOfDay(date: object.date), cals:object.calories))
        }
        
        if settingsObj.manualMode == false {
            let everyDay = DateComponents(day:1)
            let queryPeriod = HKQuery.predicateForSamples(withStart: self.startDate, end: self.endDate, options:.strictEndDate)
            let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate,queryPeriod])
            
            hkPackets = await withCheckedContinuation { continuation in
                let actCalsQuery = HKStatisticsCollectionQuery(quantityType: eatenQuantityType, quantitySamplePredicate: queryPredicate, options: .cumulativeSum, anchorDate: self.startDate, intervalComponents: everyDay)
                
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
                    
                    var packetsToAdd: [CalsPacket] = []
                    
                    actCollection.enumerateStatistics(from: self.startDate, to: self.endDate)
                    { statistics, _ in
                        if let quantity = statistics.sumQuantity(){
                            let date = statistics.startDate
                            
                            let value = Int(quantity.doubleValue(for: .kilocalorie()))
                            
                            packetsToAdd.append(CalsPacket(date:date, cals:value))
                        }
                    }
                    
                    continuation.resume(returning: packetsToAdd)
                }
                
                healthStore.execute(actCalsQuery)
            }
        }
        
        return (budgie: budgiePackets, hk: hkPackets)
    }
        
    @MainActor func assembleChartData()
    {
        var returnValue: [ChartDataLump] = []
        
        if settingsObj.manualMode == true || self.actAsIfManual == true {
            var iterateDate = self.startDate
            while iterateDate < self.endDate {
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
        self.cleanDataObject()
        self.updateInProgress = false
    }
}
