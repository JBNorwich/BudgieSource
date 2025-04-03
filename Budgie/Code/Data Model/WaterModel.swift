//
//  WaterModel.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 22/03/2025.
//

import SwiftUI
import SwiftData
import HealthKit

@Model final class WaterEntry: Sendable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var quantity: Int
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
        modelContext.insert(object)
        do {
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
