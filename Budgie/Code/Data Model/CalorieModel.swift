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
        if name != "" {
            self.name = name
        } else {
            self.name = "Unnamed meal"
        }
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
        self.narrative = narrative ?? nil
        self.isInHK = isInHK
        self.realEntry = true
        self.meal = mealUUID
        if (self.isInHK) == false {
            self.healthKitUUID = nil
        } else {
            if healthKitUUID != nil {
                self.healthKitUUID = healthKitUUID
            } else {
                self.healthKitUUID = nil
                self.isInHK = false
            }
        }
    }
    
    func delete(context: ModelContext) {
        do {
            context.delete(self)
            try context.save()
        } catch {
            print("Error deleting calories: \(error)")
        }
    }
}

/// Actor to act on the CalorieEntry database.
@ModelActor
actor CalorieActor {
    func fetchCalsBetween(from: Date,to: Date) async -> [CalorieEntry]{
        let searchPredicate = #Predicate<CalorieEntry> { entry in
            (entry.date > from) && (entry.date < to)
        }
        let descriptor = FetchDescriptor<CalorieEntry>(predicate: searchPredicate)
        return await withCheckedContinuation { continuation in
            do {
                let returns = try modelContext.fetch(descriptor)
                if returns.count != 0 {
                    continuation.resume(returning: returns)
                } else {
                    continuation.resume(returning: [])
                }
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    func fetchCalsByString(search: String?, meal: Meal?) async -> [CalorieEntry] {
        var searchPredicate: Predicate<CalorieEntry>
        if search != nil {
            if meal == nil {
                searchPredicate = #Predicate<CalorieEntry> { entry in
                    entry.narrative != nil && entry.calories != 0 && entry.narrative!.contains(search!)
                }
            } else {
                let mealUUID = meal!.mealUUID
                searchPredicate = #Predicate<CalorieEntry> { entry in
                    entry.narrative != nil && entry.calories != 0 && entry.narrative!.contains(search!) && entry.meal == mealUUID
                }
            }
        } else {
            return []
        }
        var descriptor = FetchDescriptor<CalorieEntry>(predicate: searchPredicate, sortBy: [SortDescriptor(\CalorieEntry.date, order: .reverse)])
        descriptor.fetchLimit = 50
        
        return await withCheckedContinuation { continuation in
            do {
                let returns: [CalorieEntry] = try modelContext.fetch(descriptor)
                var actualReturns: [CalorieEntry] = []
                for item in returns {
                    var dupe: Bool = false
                    for inActual in actualReturns {
                        if item.narrative == inActual.narrative && item.narrative != nil && item.calories == inActual.calories {
                            dupe = true
                        }
                    }
                    if dupe != true {
                        actualReturns.append(item)
                    }
                }
                continuation.resume(returning: actualReturns)
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    func fetchCalsForMeal(_ meal: Meal?) async -> [CalorieEntry] {
        var searchPredicate: Predicate<CalorieEntry>
        if meal != nil {
            let mealUUID = meal!.mealUUID
            searchPredicate = #Predicate<CalorieEntry> { entry in
                entry.meal == mealUUID
            }
        } else {
            searchPredicate = #Predicate<CalorieEntry> { entry in
                entry.calories != 0
            }
        }
        var descriptor = FetchDescriptor<CalorieEntry>(predicate: searchPredicate, sortBy: [SortDescriptor(\CalorieEntry.date, order: .reverse)])
        descriptor.fetchLimit = 100
        
        return await withCheckedContinuation { continuation in
            do {
                let returns: [CalorieEntry] = try modelContext.fetch(descriptor)
                var actualReturns: [CalorieEntry] = []
                for item in returns {
                    var dupe: Bool = false
                    for inActual in actualReturns {
                        if item.narrative == inActual.narrative && item.narrative != nil && item.calories == inActual.calories {
                            dupe = true
                        }
                    }
                    if dupe != true {
                        actualReturns.append(item)
                    }
                }
                continuation.resume(returning: actualReturns)
            } catch {
                continuation.resume(returning: [])
            }
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
        var returnedMealUUIDs: [UUID] = []
        var returnedMeals: [Meal] = []
        let fullMealList = getListOfMeals()
        
        for entry in data {
            if !returnedMealUUIDs.contains(entry.meal) {
                returnedMealUUIDs.append(entry.meal)
            }
        }
        
        for uuid in returnedMealUUIDs {
            for meal in fullMealList {
                if meal.mealUUID == uuid {
                    returnedMeals.append(meal)
                }
            }
        }
        
        returnedMeals.sort { $0.order < $1.order }
        return returnedMeals
    }
    
    func getMealUUIDbyName(name: String) async -> UUID {
        let searchPredicate = #Predicate<Meal> { meal in
            meal.name == "\(name)"
        }
        let descriptor = FetchDescriptor<Meal>(predicate: searchPredicate)
        let returnval = await withCheckedContinuation { continuation in
            do {
                let returns = try modelContext.fetch(descriptor)
                continuation.resume(returning: returns)
            } catch {
                ///error handling
            }
        }
        return returnval.first(where: { $0.name == name })!.mealUUID
    }
    
    func deleteEntries(objects: [CalorieEntry])
    {
        for object in objects {
            do {
                if object.isInHK == true {
                    Task {
                        if object.healthKitUUID != nil {
                            if healthStore.authorizationStatus(for: eatenQuantityType) == HKAuthorizationStatus.sharingAuthorized
                            {
                                let hkUUIDPredicate = HKQuery.predicateForObjects(with: [object.healthKitUUID!])
                                
                                do {
                                    try await healthStore.deleteObjects(of: eatenQuantityType, predicate: hkUUIDPredicate)
                                } catch {
                                    //Nothing. This is not recoverable.
                                }
                            }
                        }
                    }
                }
                let uuidToDelete = object.id
                try modelContext.delete(model: CalorieEntry.self, where: #Predicate<CalorieEntry> { ($0.id == uuidToDelete) }, includeSubclasses: true)
            } catch {
                print("Calorie deletion error: \(error)")
            }
        }
        do {
            try modelContext.save()
        } catch {
            // Nothing. Not recoverable.
        }
    }
}
