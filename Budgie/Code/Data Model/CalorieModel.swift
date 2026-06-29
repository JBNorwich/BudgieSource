//
//  CalorieModel.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 25/08/2024.
//

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

struct MealEntity: AppEntity, Identifiable {
    var id: UUID
    
    @Property(title: "Meal")
    var name: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static var defaultQuery = StructMealQuery()
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Meal"
    
    // the UUID here is the internal "mealUUID" of the Meal object in the data store
    init(mealUUID: UUID, name: String) {
        self.id = mealUUID
        self.name = name
    }
}

struct StructMealQuery: EntityQuery {
    func entities(for identifiers: [MealEntity.ID]) async throws -> [MealEntity] {
        print("Calling for MealEntities via entities!")
        let mealObjects = await dataStore.calorieActor.getListOfMeals()
        return mealObjects
            .filter { identifiers.contains($0.mealUUID) }
            .map { MealEntity(mealUUID: $0.mealUUID, name: $0.name) }
    }
    
    func suggestedEntities() async throws -> [MealEntity] {
        print("Calling for MealEntities via SuggestedEntities!")
        let mealObjects = await dataStore.calorieActor.getListOfMeals()
        return mealObjects.map { MealEntity(mealUUID: $0.mealUUID, name: $0.name) }
    }
}

@Model
final class CalorieEntry {
    private(set) var id: UUID = UUID()
    var date: Date = Date()
    var calories: Int = 0
    var narrative: String?
    var isInHK: Bool = false
    var healthKitUUID: UUID?
    var realEntry: Bool = true
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
        descriptor.fetchLimit = 30
        
        return await withCheckedContinuation { continuation in
            do {
                let returns: [CalorieEntry] = try modelContext.fetch(descriptor)
                continuation.resume(returning: returns)
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
                                    //balls!
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
            // nothing
        }
    }
}
