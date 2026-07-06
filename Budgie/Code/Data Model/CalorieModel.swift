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
import SwiftData
#if !os(macOS)
import HealthKit
#endif
import AppIntents

@Model final class Meal {
    private(set) var id: UUID = UUID()
    var mealUUID: UUID = UUID()
    /// The title of the meal
    var name: String = "Meal"
    /// Absolute order in the list of meals.
    var order: Int = 0
    /// Percentage of the budget allocated to this meal, if that feature is turned on. 0 is unallocated.
    var budgetPercent: Double = 0
    
    init(name: String, order: Int) {
        self.name = name.isEmpty ? "Unnamed meal" : name
        self.order = order
    }
}

/// SwiftData class for individual food entries.
@Model
final class CalorieEntry {
    private(set) var id: UUID = UUID()
    /// The date and time of the calorie entry.
    var date: Date = Date()
    /// The number of calories, as an integer.
    var calories: Int = 0
    /// Optional variable which describes what the food is. Budgie Diet will unwrap this to "Quick calories" if left blank or as nil.
    var narrative: String?
    /// Boolean that indicates whether the entry is in HealthKit.
    var isInHK: Bool = false
    /// The UUID of the matching entry in HealthKit.
    var healthKitUUID: UUID?
    /// Indicates whether this CalorieEntry is a real one, or a dummy one for display purposes.
    var realEntry: Bool = true
    /// The mealUUID of the meal which this food is allocated to.
    var meal: UUID = UUID()
    
    init(date: Date, calories: Int, narrative: String?, mealUUID: UUID, isInHK: Bool, healthKitUUID: UUID?) {
        self.date = date
        self.calories = calories
        self.narrative = narrative
        self.isInHK = isInHK
        self.realEntry = true
        self.meal = mealUUID
        self.healthKitUUID = isInHK ? healthKitUUID : nil
        self.isInHK = self.healthKitUUID != nil
    }
}

/// Actor to act on the CalorieEntry database.
@ModelActor
actor CalorieActor {
    func fetchCalsBetween(from: Date, to: Date) async -> [CalorieEntry] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let descriptor = FetchDescriptor<CalorieEntry>(
            predicate: #Predicate<CalorieEntry> { $0.date > from && $0.date < to }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchCalsForMeal(_ meal: Meal?) async -> [CalorieEntry] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        var searchPredicate: Predicate<CalorieEntry>
        if meal != nil {
            let mealUUID = meal!.mealUUID
            searchPredicate = #Predicate<CalorieEntry> { entry in
                entry.meal == mealUUID
            }
        } else {
            searchPredicate = #Predicate<CalorieEntry> { _ in true }
        }
        var descriptor = FetchDescriptor<CalorieEntry>(predicate: searchPredicate, sortBy: [SortDescriptor(\CalorieEntry.date, order: .reverse)])
        descriptor.fetchLimit = 100
        
        guard let results = try? modelContext.fetch(descriptor) else { return [] }
        var seenKeys = Set<String>()
        return results.filter { entry in
            guard let narrative = entry.narrative else { return true }
            return seenKeys.insert("\(narrative)|\(entry.calories)").inserted
        }
    }
    
    func searchCals(term: String, meal: UUID?, limit: Int = 50) async -> [CalorieEntry] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let predicate: Predicate<CalorieEntry>
        if let meal {
            predicate = #Predicate { $0.meal == meal && ($0.narrative?.localizedStandardContains(term) ?? false) }
        } else {
            predicate = #Predicate { $0.narrative?.localizedStandardContains(term) ?? false }
        }
        var descriptor = FetchDescriptor<CalorieEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        guard let results = try? modelContext.fetch(descriptor) else { return [] }

        // Same dedup as fetchCalsForMeal.
        var seen = Set<String>()
        return results.filter { entry in
            guard let n = entry.narrative else { return true }
            return seen.insert("\(n)|\(entry.calories)").inserted
        }
    }
    
    func insertNewCals(object: CalorieEntry)
    {

        do {
            modelContext.insert(object)
            try modelContext.save()
        } catch {
            print("Calorie insertion error: \(error)")
        }
    }
    
    func getListOfMeals() -> [Meal] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        do {
            let returns = try modelContext.fetch(FetchDescriptor<Meal>())
            return returns
        } catch {
            return []
        }
    }
    
    func setUpMeals() {
        let breakfast = Meal(name: "Breakfast", order: 0)
        let lunch = Meal(name: "Lunch", order: 1)
        let dinner = Meal(name: "Dinner", order: 2)
        let snacks = Meal(name: "Snacks/Other", order: 3)

        do {
            modelContext.insert(breakfast)
            modelContext.insert(lunch)
            modelContext.insert(dinner)
            modelContext.insert(snacks)
            try modelContext.save()
        } catch {
            print("Error setting up meals: \(error)")
        }
    }
    
    func cleansedMealList(data: [CalorieEntry]) -> [Meal] {
        let usedMealUUIDs = Set(data.map(\.meal))
        return getListOfMeals()
            .filter { usedMealUUIDs.contains($0.mealUUID) }
            .sorted { $0.order < $1.order }
    }
    
    func getMealUUIDbyName(name: String) async -> UUID? {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate<Meal> { $0.name == name })
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.first?.mealUUID
    }
    
    func updateCalories(entry: CalorieEntry, calories: Int, narrative: String?, date: Date, meal: UUID) async {
        #if !os(macOS)
        // HK can't be updated in place — delete the old sample, then write a fresh one.
        if entry.isInHK, let oldUUID = entry.healthKitUUID {
            await dataStore.deleteHKSample(uuid: oldUUID, type: eatenQuantityType)
        }
        let newUUID = entry.isInHK ? await dataStore.saveHKSample(value: Double(calories), unit: .kilocalorie(), type: eatenQuantityType, date: date) : nil
        #endif
        
        // SwiftData, unlike HK, can just be mutated — this preserves the entry's identity.
        entry.calories = calories
        entry.narrative = (narrative?.isEmpty ?? true) ? "Quick calories" : narrative!
        entry.date = date
        entry.meal = meal
        
        #if !os(macOS)
        entry.isInHK = newUUID != nil
        entry.healthKitUUID = newUUID
        #endif
        
        do {
            try modelContext.save()
        } catch {
            // Not recoverable.
        }
    }
    
    func deleteEntries(objects: [CalorieEntry]) async {
        for object in objects {
            #if !os(macOS)
            if object.isInHK, let hkUUID = object.healthKitUUID {
                await dataStore.deleteHKSample(uuid: hkUUID, type: eatenQuantityType)
            }
            #endif
            modelContext.delete(object)
        }
        do {
            try modelContext.save()
        } catch {
            // Not recoverable.
        }
    }
    
    /// Adds a new meal, placed after the current highest-ordered meal.
    func addMeal(name: String) {
        let nextOrder = (getListOfMeals().map(\.order).max() ?? -1) + 1
        let meal = Meal(name: name.trimmingCharacters(in: .whitespacesAndNewlines), order: nextOrder)
        modelContext.insert(meal)
        do { try modelContext.save() } catch { print("Meal insertion error: \(error)") }
    }
    
    /// Renames the meal identified by `mealUUID`. Empty names fall back to "Unnamed meal".
    func renameMeal(mealUUID: UUID, newName: String) {
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate<Meal> { $0.mealUUID == mealUUID })
        guard let meal = (try? modelContext.fetch(descriptor))?.first else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        meal.name = trimmed.isEmpty ? "Unnamed meal" : trimmed
        do { try modelContext.save() } catch { print("Meal rename error: \(error)") }
    }
    
    /// Persists a new display order. `orderedUUIDs` lists the meal UUIDs in the desired order.
    func reorderMeals(orderedUUIDs: [UUID]) {
        let meals = getListOfMeals()
        for (index, uuid) in orderedUUIDs.enumerated() {
            meals.first(where: { $0.mealUUID == uuid })?.order = index
        }
        do { try modelContext.save() } catch { print("Meal reorder error: \(error)") }
    }
    
    /// Deletes a meal, first moving every CalorieEntry assigned to it onto `reassignTo`.
    /// `protectedUUID` (the Snacks/Other meal) can never be deleted — the call is a no-op if it matches.
    func deleteMeal(mealUUID: UUID, reassignTo: UUID, protectedUUID: UUID?) {
        guard mealUUID != reassignTo else { return }
        guard mealUUID != protectedUUID else { return }

        // Move all entries off the doomed meal. Meal assignment is a Budgie Diet-only concept,
        // so there is nothing to update in HealthKit here.
        let entryDescriptor = FetchDescriptor<CalorieEntry>(predicate: #Predicate<CalorieEntry> { $0.meal == mealUUID })
        let entries = (try? modelContext.fetch(entryDescriptor)) ?? []
        for entry in entries { entry.meal = reassignTo }

        // Delete the meal itself.
        let mealDescriptor = FetchDescriptor<Meal>(predicate: #Predicate<Meal> { $0.mealUUID == mealUUID })
        if let meal = (try? modelContext.fetch(mealDescriptor))?.first {
            modelContext.delete(meal)
        }

        do { try modelContext.save() } catch { print("Meal deletion error: \(error)") }
    }
    
    /// Writes per-meal budget percentages. Values are clamped to 0...100.
    func setMealAllocations(_ allocations: [UUID: Double]) {
        let meals = getListOfMeals()
        for meal in meals {
            if let pct = allocations[meal.mealUUID] {
                meal.budgetPercent = max(0, min(100, pct))
            }
        }
        do { try modelContext.save() } catch { print("Allocation save error: \(error)") }
    }
    
    /// Merges meals that share a name (e.g. duplicates created when two devices both seeded the defaults before CloudKit synced). Keeps one copy of each name - preferring `preferredSurvivor` (the stored Snacks/Other UUID), then the lowest order - moves the duplicates' entries across, and deletes the rest.
    func dedupeMeals(preferredSurvivor: UUID?) {
        let meals = getListOfMeals().sorted {
            if $0.mealUUID == preferredSurvivor { return true }
            if $1.mealUUID == preferredSurvivor { return false }
            return $0.order < $1.order
        }
        var keptByName: [String: Meal] = [:]
        var changed = false
        for meal in meals {
            if let survivor = keptByName[meal.name] {
                let doomedUUID = meal.mealUUID
                let survivorUUID = survivor.mealUUID
                let descriptor = FetchDescriptor<CalorieEntry>(predicate: #Predicate<CalorieEntry> { $0.meal == doomedUUID })
                for entry in (try? modelContext.fetch(descriptor)) ?? [] { entry.meal = survivorUUID }
                modelContext.delete(meal)
                changed = true
            } else {
                keptByName[meal.name] = meal
            }
        }
        if changed {
            do { try modelContext.save() } catch { print("Meal dedupe error: \(error)") }
        }
    }
    
    /// Records the HealthKit sample UUID for an entry mirrored during reconciliation.
    func markCalorieMirrored(entryID: UUID, healthKitUUID: UUID) {
        let descriptor = FetchDescriptor<CalorieEntry>(predicate: #Predicate { $0.id == entryID })
        guard let entry = (try? modelContext.fetch(descriptor))?.first else { return }
        entry.healthKitUUID = healthKitUUID
        entry.isInHK = true
        try? modelContext.save()
    }
}
