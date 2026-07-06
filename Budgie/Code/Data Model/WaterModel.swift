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
#if !os(macOS)
import HealthKit
#endif

@Model final class WaterEntry {
    // Class used by the model for a single entry of hydration into the app
    
    var id: UUID = UUID()
    var date: Date = Date()
    var quantity: Int = 0
    var healthKitUUID: UUID?
    
    init(quantity: Int, healthKitUUID: UUID? = nil, date: Date = Date()) {
        self.date = date
        self.quantity = quantity
        self.healthKitUUID = healthKitUUID
    }
}

@ModelActor actor WaterActor {
    func addWater(object: WaterEntry) async {
        modelContext.insert(object)
        do {
            try modelContext.save()
        } catch {
            #if !os(macOS)
            if let hkUUID = object.healthKitUUID {
                await dataStore.deleteHKSample(uuid: hkUUID, type: waterQuantityType)
            }
            #endif
            print("Water insertion error: \(error)")
        }
    }
    
    func deleteEntries(objects: [WaterEntry]) async {
        for object in objects {
            #if !os(macOS)
            if let hkUUID = object.healthKitUUID {
                await dataStore.deleteHKSample(uuid: hkUUID, type: waterQuantityType)
            }
            #endif
            modelContext.delete(object)
        }
        do {
            try modelContext.save()
        } catch {
            print("Water deletion error: \(error)")
        }
    }
    
    func getTotalOnDate(date: Date) async -> Int {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let start = getStartOfDay(date: date)
        let end = getMidnightOnDayAfter(date: start)
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.date > start && $0.date < end })
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        return entries.reduce(0) { $0 + $1.quantity }
    }

    func getEntriesOnDate(date: Date) async -> [WaterEntry] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let start = getStartOfDay(date: date)
        let end = getMidnightOnDayAfter(date: start)
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.date > start && $0.date < end })
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchWaterBetween(from: Date, to: Date) async -> [WaterEntry] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.date > from && $0.date < to })
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func markWaterMirrored(entryID: UUID, healthKitUUID: UUID) {
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.id == entryID })
        guard let entry = (try? modelContext.fetch(descriptor))?.first else { return }
        entry.healthKitUUID = healthKitUUID
        try? modelContext.save()
    }
}
