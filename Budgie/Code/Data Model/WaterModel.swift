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
import HealthKit

@Model final class WaterEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var quantity: Int = 0
    var healthKitUUID: UUID?
    
    init(date: Date?, quantity: Int, healthKitUUID: UUID?) {
        self.id = UUID()
        if date != nil {
            self.date = date!
        } else {
            self.date = Date()
        }
        self.quantity = quantity
        if healthKitUUID != nil {
            self.healthKitUUID = healthKitUUID
        }
    }
}

@ModelActor actor WaterActor {
    func addWater(object: WaterEntry) {
        do {
            modelContext.insert(object)
            try modelContext.save()
        } catch {
            print("Water insertion error: \(error)")
        }
    }
    
    func deleteEntries(objects: [WaterEntry]) {
        for object in objects {
            if object.healthKitUUID != nil {
                Task {
                    if healthStore.authorizationStatus(for: waterQuantityType) == HKAuthorizationStatus.sharingAuthorized {
                        let hkUUIDPredicate = HKQuery.predicateForObjects(with: [object.healthKitUUID!])
                        
                        try await healthStore.deleteObjects(of: waterQuantityType, predicate: hkUUIDPredicate)
                    }
                }
            }
            modelContext.delete(object)
        }
        do {
            try modelContext.save()
        } catch {
            print("Water deletion error: \(error)")
        }
    }
    
    func getTotalOnDate(date: Date) async -> Int {
        let start = getStartOfDay(date: date)
        let end = getMidnightOnDayAfter(date: start)
        let searchPredicate = #Predicate<WaterEntry> { entry in
            entry.date > start && entry.date < end
        }
        let descriptor = FetchDescriptor<WaterEntry>(predicate: searchPredicate)
        return await withCheckedContinuation { continuation in
            do {
                let returns = try modelContext.fetch(descriptor)
                var sum: Int = 0
                if returns.count == 0 {
                    continuation.resume(returning: sum)
                } else {
                    for entry in returns {
                        sum = sum + entry.quantity
                    }
                    continuation.resume(returning: sum)
                }
            } catch {
                continuation.resume(returning: 0)
            }
        }
    }
    
    func getEntriesOnDate(date: Date) async -> [WaterEntry] {
        let start = getStartOfDay(date: date)
        let end = getMidnightOnDayAfter(date: start)
        let searchPredicate = #Predicate<WaterEntry> { entry in
            entry.date > start && entry.date < end
        }
        let descriptor = FetchDescriptor<WaterEntry>(predicate: searchPredicate)
        return await withCheckedContinuation { continuation in
            do {
                let returns = try modelContext.fetch(descriptor)
                if returns.count == 0 {
                    continuation.resume(returning: [])
                } else {
                    continuation.resume(returning: returns)
                }
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}
