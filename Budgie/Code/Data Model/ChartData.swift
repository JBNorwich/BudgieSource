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

@MainActor
class ChartData: ObservableObject {
    static let shared = ChartData()
    
    @Published var returnedChartData: [ChartDataLump] = []
    var activePackets: [CalsPacket] = []
    var basalPackets: [CalsPacket] = []
    var eatenPackets: [CalsPacket] = []
    var budgieEatenPackets: [CalsPacket] = []
    var startDate: Date = Date()
    var endDate: Date = Date()
    @Published var dataUpdated: Bool = false
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
    }
    
    func pokeForUpdate() async
    {
        if self.updateInProgress == false {
            self.updateInProgress = true
            self.activePackets = await fetchChartActive()
            self.basalPackets = await fetchChartBasal()
            let eatenPacketsReturn = await fetchChartEaten()
            self.eatenPackets = eatenPacketsReturn.hk
            self.budgieEatenPackets = eatenPacketsReturn.budgie
            self.dataUpdated = true
        }
    }
    
    private func runCumulativeQuery(quantityType: HKQuantityType, predicate: NSPredicate, anchorDate: Date) async -> [CalsPacket] {
        let everyDay = DateComponents(day: 1)
        let queryStart = self.startDate   // read while still on the main actor
        let queryEnd = self.endDate       // read while still on the main actor
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum, anchorDate: anchorDate, intervalComponents: everyDay)
            query.initialResultsHandler = { _, results, error in
                if error is HKError {
                    continuation.resume(returning: [])
                    return
                }
                guard let collection = results else {
                    assertionFailure("")
                    continuation.resume(returning: [])
                    return
                }
                var packets: [CalsPacket] = []
                collection.enumerateStatistics(from: queryStart, to: queryEnd) { statistics, _ in
                    if let quantity = statistics.sumQuantity() {
                        let value = Int(quantity.doubleValue(for: .kilocalorie()).rounded())
                        packets.append(CalsPacket(date: statistics.startDate, cals: value))
                    }
                }
                continuation.resume(returning: packets)
            }
            healthStore.execute(query)
        }
    }
    
    func fetchChartActive() async -> [CalsPacket] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        return await runCumulativeQuery(quantityType: activeQuantityType, predicate: predicate, anchorDate: startDate)
    }

    func fetchChartBasal() async -> [CalsPacket] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let packets = await runCumulativeQuery(quantityType: basalQuantityType, predicate: predicate, anchorDate: startDate)
        return packets
    }

    func fetchChartEaten() async -> (budgie: [CalsPacket], hk: [CalsPacket]) {
        let objArray = await dataStore.calorieActor.fetchCalsBetween(from: startDate, to: endDate)
        let budgiePackets = objArray.map { CalsPacket(date: getStartOfDay(date: $0.date), cals: $0.calories) }

        let queryPeriod = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notBudgiePredicate, queryPeriod])
        let hkPackets = await runCumulativeQuery(quantityType: eatenQuantityType, predicate: queryPredicate, anchorDate: startDate)

        return (budgie: budgiePackets, hk: hkPackets)
    }
        
    func assembleChartData()
    {
        var lumpsByDate: [Date: ChartDataLump] = [:]
        
        for basalStruct in basalPackets where basalStruct.date < endDate {
            let newLump = ChartDataLump()
            newLump.date = basalStruct.date
            newLump.basalCals = basalStruct.cals
            lumpsByDate[basalStruct.date] = newLump
        }
        
        for activeStruct in activePackets {
            lumpsByDate[activeStruct.date]?.activeCals = activeStruct.cals
        }
        
        for eatenStruct in eatenPackets {
            lumpsByDate[eatenStruct.date]?.eatenCals = eatenStruct.cals
        }
        for budgieStruct in budgieEatenPackets {
            lumpsByDate[budgieStruct.date]?.eatenCals += budgieStruct.cals
        }
        
        dataUpdated = false
        returnedChartData = lumpsByDate.values.sorted { $0.date < $1.date }
        cleanDataObject()
        updateInProgress = false
    }
}
