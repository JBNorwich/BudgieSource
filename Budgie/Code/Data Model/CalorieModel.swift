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
import HealthKit
import AppIntents

@Model final class Meal {
    private(set) var id: UUID = UUID()
    var mealUUID: UUID = UUID()
    var name: String = "Meal"
    var order: Int = 0
    
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
        let descriptor = FetchDescriptor<CalorieEntry>(
            predicate: #Predicate<CalorieEntry> { $0.date > from && $0.date < to }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchCalsForMeal(_ meal: Meal?) async -> [CalorieEntry] {
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
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate<Meal> { $0.name == name })
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.first?.mealUUID
    }
    
    func updateCalories(entry: CalorieEntry, calories: Int, narrative: String?, date: Date, meal: UUID) async {
        // HK can't be updated in place — delete the old sample, then write a fresh one.
        if entry.isInHK, let oldUUID = entry.healthKitUUID {
            await dataStore.deleteHKSample(uuid: oldUUID, type: eatenQuantityType)
        }
        let newUUID = entry.isInHK ? await dataStore.saveHKSample(value: Double(calories), unit: .kilocalorie(), type: eatenQuantityType, date: date) : nil

        // SwiftData, unlike HK, can just be mutated — this preserves the entry's identity.
        entry.calories = calories
        entry.narrative = (narrative?.isEmpty ?? true) ? "Quick calories" : narrative!
        entry.date = date
        entry.meal = meal
        entry.isInHK = newUUID != nil
        entry.healthKitUUID = newUUID

        do {
            try modelContext.save()
        } catch {
            // Not recoverable.
        }
    }
    
    func deleteEntries(objects: [CalorieEntry]) async {
        for object in objects {
            if object.isInHK, let hkUUID = object.healthKitUUID {
                await dataStore.deleteHKSample(uuid: hkUUID, type: eatenQuantityType)
            }
            modelContext.delete(object)
        }
        do {
            try modelContext.save()
        } catch {
            // Not recoverable.
        }
    }
}
