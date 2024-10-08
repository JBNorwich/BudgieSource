//
//  CalorieModel.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 25/08/2024.
//

import Foundation
import SwiftData

@Model class Meal {
    @Attribute(.unique) var id: UUID
    var mealUUID: UUID
    var name: String
    var order: Int
    
    init(name: String, order: Int) {
        self.id = UUID()
        self.mealUUID = UUID()
        if name != "" {
            self.name = name
        } else {
            self.name = "Unnamed meal"
        }
        self.order = order
    }
}

@Model
class CalorieEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var calories: Int
    var narrative: String?
    var isInHK: Bool
    var healthKitUUID: UUID?
    var realEntry: Bool
    var meal: UUID
    
    init(date: Date, calories: Int, narrative: String?, mealUUID: UUID, isInHK: Bool, healthKitUUID: UUID?) {
        self.id = UUID()
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
        if self.isInHK == true {
            Task {
                await HealthData().deleteCalorieEntries(calorieObjects:[self])
            }
        }
        do {
            context.delete(self)
            try context.save()
        } catch {
            print("Error deleting calories: \(error)")
        }
    }
}

class CalorieData: ObservableObject {
    let calorieContainer = try! ModelContainer(for: CalorieEntry.self,Meal.self)
    
    private var context: ModelContext
    
    @MainActor init() {
        context = calorieContainer.mainContext
    }
    
    func fetchCalsBetween(from: Date,to: Date) -> [CalorieEntry]{
        let searchPredicate = #Predicate<CalorieEntry> { entry in
            (entry.date > from) && (entry.date < to)
        }
        var returns: [CalorieEntry] = []
        let descriptor = FetchDescriptor<CalorieEntry>(predicate: searchPredicate)
        do {
            returns = try context.fetch(descriptor)
        } catch {
            ///error handling
        }
        
        return returns
    }
    
    func insertNewCals(object: CalorieEntry)
    {
        self.context.insert(object)
        do {
            try self.context.save()
        } catch {
            print("Calorie insertion error: \(error)")
        }
    }
    
    func deleteEntries(objects: [CalorieEntry])
    {
        for object in objects {
            do {
                let uuidToDelete = object.id
                try context.delete(model: CalorieEntry.self, where: #Predicate<CalorieEntry> { ($0.id == uuidToDelete) }, includeSubclasses: true)
            } catch {
                print("Calorie deletion error: \(error)")
            }
        }
        do {
            try context.save()
        } catch {
            // nothing
        }
    }
    
    @MainActor func getListOfMeals() -> [Meal] {
        do {
            let returns = try context.fetch(FetchDescriptor<Meal>())
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
        self.context.insert(breakfast)
        self.context.insert(lunch)
        self.context.insert(dinner)
        self.context.insert(snacks)
        do {
            try context.save()
        } catch {
            print("Error setting up meals: \(error)")
        }
    }
    
    @MainActor func cleansedMealList(data: [CalorieEntry]) -> [Meal] {
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
}
