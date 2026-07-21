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
    
    var syncNonce: Int = 0
}

extension WaterEntry {
    convenience init(restoring dto: WaterEntryDTO) {
        self.init(quantity: dto.quantity, healthKitUUID: dto.healthKitUUID, date: dto.date)
        self.id = dto.id
        self.syncNonce = dto.syncNonce
    }
}

@ModelActor actor WaterActor {
    private func save(_ label: String) {
        do { try modelContext.save() } catch { print("\(label) error: \(error)") }
    }

    /// Fetches with the standard `#if os(macOS) modelContext.rollback() #endif` guard applied first.
    private func fetch<T>(_ descriptor: FetchDescriptor<T>) -> [T] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        return (try? modelContext.fetch(descriptor)) ?? []
    }

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
        save("Water deletion")
    }

    func getTotalOnDate(date: Date) async -> Int {
        let start = getStartOfDay(date: date)
        let end = getMidnightOnDayAfter(date: start)
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.date > start && $0.date < end })
        return fetch(descriptor).reduce(0) { $0 + $1.quantity }
    }

    func getEntriesOnDate(date: Date) async -> [WaterEntry] {
        let start = getStartOfDay(date: date)
        let end = getMidnightOnDayAfter(date: start)
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.date > start && $0.date < end })
        return fetch(descriptor)
    }

    func fetchWaterBetween(from: Date, to: Date) async -> [WaterEntry] {
        fetch(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.date > from && $0.date < to }))
    }

    func markWaterMirrored(entryID: UUID, healthKitUUID: UUID) {
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.id == entryID })
        guard let entry = (try? modelContext.fetch(descriptor))?.first else { return }
        entry.healthKitUUID = healthKitUUID
        try? modelContext.save()
    }

    // MARK: - Backup / restore

    func exportWater() -> [WaterEntryDTO] {
        ((try? modelContext.fetch(FetchDescriptor<WaterEntry>())) ?? []).map(WaterEntryDTO.init)
    }

    func wipeWater() {
        for e in (try? modelContext.fetch(FetchDescriptor<WaterEntry>())) ?? [] { modelContext.delete(e) }
        save("Water wipe")
    }

    @discardableResult
    func importWater(_ dtos: [WaterEntryDTO], merge: Bool) -> Int {
        let existing = merge ? Set(((try? modelContext.fetch(FetchDescriptor<WaterEntry>())) ?? []).map(\.id)) : []
        var count = 0
        for dto in dtos where !existing.contains(dto.id) { modelContext.insert(WaterEntry(restoring: dto)); count += 1 }
        save("Water import")
        return count
    }
}
