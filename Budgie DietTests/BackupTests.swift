//
//  BackupTests.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 12/07/2026.
//


import Testing
import Foundation
import SwiftData
@testable import Budgie_Diet

@Suite(.serialized)
struct BackupTests {

    private func makeStore() throws -> ModelContainer {
        try ModelContainer(
            for: CalorieEntry.self, FoodItem.self, Meal.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
    
    /// Water lives in its own "waterDB" configuration in the app (see HealthData), so the test
    /// container must mirror that. A default-config store makes WaterEntry inserts trap with
    /// "store does not contain the object's entity" once the host app has registered the real schema.
    private func makeWaterStore() throws -> ModelContainer {
        try ModelContainer(
            for: WaterEntry.self,
            configurations: ModelConfiguration("waterDB", schema: Schema([WaterEntry.self]),
                                               isStoredInMemoryOnly: true)
        )
    }

    /// All-nil settings, so a round-trip test doesn't depend on global app state.
    private func emptySettings() throws -> SettingsDTO {
        try JSONDecoder().decode(SettingsDTO.self, from: Data("{}".utf8))
    }

    // 1. The fiddly new stamped fields (and the serving-unit enum) survive JSON encode→decode.
    @Test func encodeDecodePreservesStampedEntryFields() throws {
        let foodID = UUID(), hkID = UUID()
        let entry = CalorieEntry(date: Date(timeIntervalSince1970: 1_000_000), calories: 250,
                                 narrative: "Bar", mealUUID: UUID(), isInHK: true, healthKitUUID: hkID,
                                 item: foodID, manufacturer: "Acme", unit: .grams, servings: 40,
                                 protein: 12, fat: 8, carbs: 30)
        let backup = BudgieBackup(schemaVersion: BackupService.schemaVersion,
                                  exportDate: Date(timeIntervalSince1970: 2_000_000), appVersion: "3.3",
                                  settings: try emptySettings(), meals: [], foodItems: [],
                                  calorieEntries: [CalorieEntryDTO(entry)], waterEntries: [])

        let restored = try BackupService.decode(try BackupService.encode(backup))
        let dto = try #require(restored.calorieEntries.first)
        #expect(dto.calories == 250)
        #expect(dto.manufacturer == "Acme")
        #expect(dto.servingUnit == .grams)
        #expect(dto.servingAmount == 40)
        #expect(dto.protein == 12)
        #expect(dto.foodItem == foodID)
        #expect(dto.healthKitUUID == hkID)
        #expect(dto.isInHK)
    }

    // 2. FoodItem quantities, source enum and barcode survive the round-trip.
    @Test func encodeDecodePreservesFoodDetails() throws {
        let food = FoodItem(name: "Yoghurt", manufacturer: "Brand",
                            quantities: [
                                FoodQuantity(type: .grams, count: 100, calories: 60, protein: 5, carbs: 7, fat: 1),
                                FoodQuantity(type: .portion, count: 1, calories: 90, servingName: "1 pot")
                            ], source: .openFoodFacts)
        food.barcode = "5000"
        let backup = BudgieBackup(schemaVersion: 1, exportDate: .now, appVersion: nil,
                                  settings: try emptySettings(), meals: [],
                                  foodItems: [FoodItemDTO(food)], calorieEntries: [], waterEntries: [])

        let restored = try BackupService.decode(try BackupService.encode(backup))
        let dto = try #require(restored.foodItems.first)
        #expect(dto.source == .openFoodFacts)
        #expect(dto.barcode == "5000")
        #expect(dto.quantities.count == 2)
        #expect(dto.quantities[1].servingName == "1 pot")
        #expect(dto.quantities[0].protein == 5)
    }

    // 2b. Custom meal fields (components, batchYield) survive the JSON round-trip.
    @Test func encodeDecodePreservesMealComponents() throws {
        let ingredientID = UUID()
        let meal = FoodItem(name: "Sandwich", manufacturer: nil,
                            quantities: [FoodQuantity(type: .portion, count: 1, calories: 450)],
                            source: .customMeal)
        meal.components = [MealComponent(foodItemID: ingredientID, servingID: UUID(), servingUnit: .grams, servingAmount: 80)]
        meal.batchYield = 2
        let backup = BudgieBackup(schemaVersion: 1, exportDate: .now, appVersion: nil,
                                  settings: try emptySettings(), meals: [],
                                  foodItems: [FoodItemDTO(meal)], calorieEntries: [], waterEntries: [])

        let restored = try BackupService.decode(try BackupService.encode(backup))
        let dto = try #require(restored.foodItems.first)
        #expect(dto.source == .customMeal)
        #expect(dto.components?.count == 1)
        #expect(dto.components?.first?.foodItemID == ingredientID)
        #expect(dto.components?.first?.servingUnit == .grams)
        #expect(dto.components?.first?.servingAmount == 80)
        #expect(dto.batchYield == 2)
    }

    // 2c. A backup written before custom meals existed has no "components"/"batchYield" keys at
    // all. Decoding it must still succeed (not throw keyNotFound), and restoring the result must
    // produce an ordinary, non-meal food rather than crashing or guessing.
    @Test func decodingPreMealBackupJSONStillSucceeds() throws {
        let food = FoodItem(name: "Old food", manufacturer: nil,
                            quantities: [FoodQuantity(type: .portion, count: 1, calories: 100)], source: .userInput)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var json = try JSONSerialization.jsonObject(with: try encoder.encode(FoodItemDTO(food))) as! [String: Any]
        json.removeValue(forKey: "components")   // simulate a pre-meal-feature backup file
        json.removeValue(forKey: "batchYield")
        let strippedData = try JSONSerialization.data(withJSONObject: json)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FoodItemDTO.self, from: strippedData)   // must not throw
        #expect(decoded.components == nil)
        #expect(decoded.batchYield == nil)

        let rebuilt = FoodItem(restoring: decoded)
        #expect(rebuilt.components.isEmpty)
        #expect(rebuilt.batchYield == 1)
        #expect(rebuilt.source == .userInput)
    }

    // 3. Export from one store, import into a fresh one → rows rebuilt with their ids and links intact.
    @Test func exportThenImportRebuildsRowsWithSameIDs() async throws {
        let store = try makeStore()
        let ctx = ModelContext(store)
        let food = FoodItem(name: "Egg", manufacturer: nil,
                            quantities: [FoodQuantity(type: .portion, count: 1, calories: 100)], source: .userInput)
        ctx.insert(food)
        ctx.insert(Meal(name: "Breakfast", order: 0))
        ctx.insert(CalorieEntry(date: .now, calories: 100, narrative: "Egg", mealUUID: UUID(),
                                isInHK: false, healthKitUUID: nil, item: food.id, unit: .portion, servings: 1))
        try ctx.save()
        let foodID = food.id                              // capture before wipe deletes the object

        let actor = CalorieActor(modelContainer: store)
        let exported = await actor.exportFoodDomain()     // snapshot to DTOs
        await actor.wipeFoodDomain()                      // clear the store
        let inserted = await actor.importFoodDomain(meals: exported.meals, foods: exported.foods,
                                                    entries: exported.entries, merge: false)   // rebuild
        #expect(inserted.meals == 1)
        #expect(inserted.foods == 1)
        #expect(inserted.entries == 1)

        let check = ModelContext(store)
        #expect(try check.fetch(FetchDescriptor<FoodItem>()).first?.id == foodID)              // id preserved
        #expect(try check.fetch(FetchDescriptor<CalorieEntry>()).first?.foodItem == foodID)    // link intact
    }

    // 3b. A custom meal's components/batchYield survive a full actor-level export→wipe→import
    // round trip, not just a raw DTO encode/decode.
    @Test func exportThenImportPreservesMealComponents() async throws {
        let store = try makeStore()
        let ctx = ModelContext(store)
        let ingredient = FoodItem(name: "Egg", manufacturer: nil,
                                  quantities: [FoodQuantity(type: .portion, count: 1, calories: 78)], source: .userInput)
        let meal = FoodItem(name: "Breakfast", manufacturer: nil,
                            quantities: [FoodQuantity(type: .portion, count: 1, calories: 156)], source: .customMeal)
        meal.components = [MealComponent(foodItemID: ingredient.id, servingID: ingredient.quantities[0].id,
                                         servingUnit: .portion, servingAmount: 2)]
        meal.batchYield = 1
        ctx.insert(ingredient); ctx.insert(meal)
        try ctx.save()
        let mealID = meal.id, ingredientID = ingredient.id

        let actor = CalorieActor(modelContainer: store)
        let exported = await actor.exportFoodDomain()
        await actor.wipeFoodDomain()
        _ = await actor.importFoodDomain(meals: exported.meals, foods: exported.foods,
                                         entries: exported.entries, merge: false)

        let restoredMeal = try #require(try ModelContext(store).fetch(FetchDescriptor<FoodItem>())
            .first { $0.id == mealID })
        #expect(restoredMeal.source == .customMeal)
        #expect(restoredMeal.components.count == 1)
        #expect(restoredMeal.components.first?.foodItemID == ingredientID)
        #expect(restoredMeal.components.first?.servingAmount == 2)
        #expect(restoredMeal.batchYield == 1)
    }

    // 4. Merge is idempotent — re-importing the same backup inserts nothing and makes no duplicates.
    @Test func mergeImportIsIdempotent() async throws {
        let store = try makeStore()
        let foods = [FoodItemDTO(FoodItem(name: "Egg", manufacturer: nil,
                        quantities: [FoodQuantity(type: .portion, count: 1, calories: 100)], source: .userInput))]
        let meals = [MealDTO(Meal(name: "Breakfast", order: 0))]

        let actor = CalorieActor(modelContainer: store)
        _ = await actor.importFoodDomain(meals: meals, foods: foods, entries: [], merge: true)
        let second = await actor.importFoodDomain(meals: meals, foods: foods, entries: [], merge: true)
        #expect(second.meals == 0)
        #expect(second.foods == 0)
        #expect(try ModelContext(store).fetch(FetchDescriptor<FoodItem>()).count == 1)   // no duplicate
    }

    // 5. Replace wipes existing data, then restores only the backup's rows.
    @Test func wipeThenImportLeavesOnlyBackupRows() async throws {
        let store = try makeStore()
        let ctx = ModelContext(store)
        ctx.insert(FoodItem(name: "Junk", manufacturer: nil, quantities: [], source: .userInput))
        ctx.insert(Meal(name: "Old", order: 0))
        try ctx.save()

        let backupFood = FoodItemDTO(FoodItem(name: "Egg", manufacturer: nil,
                                              quantities: [FoodQuantity(type: .portion, count: 1, calories: 100)],
                                              source: .userInput))
        let actor = CalorieActor(modelContainer: store)
        await actor.wipeFoodDomain()
        _ = await actor.importFoodDomain(meals: [], foods: [backupFood], entries: [], merge: false)

        let foods = try ModelContext(store).fetch(FetchDescriptor<FoodItem>())
        #expect(foods.count == 1)
        #expect(foods.first?.name == "Egg")                                        // junk gone
        #expect(try ModelContext(store).fetch(FetchDescriptor<Meal>()).isEmpty)    // old meal wiped
    }

    // 6. Water rides along and merges idempotently too.
    @Test func waterImportIsIdempotent() async throws {
        let store = try makeWaterStore()
        let dtos = [WaterEntryDTO(WaterEntry(quantity: 250, healthKitUUID: nil, date: .now))]
        let actor = WaterActor(modelContainer: store)
        _ = await actor.importWater(dtos, merge: true)
        let second = await actor.importWater(dtos, merge: true)
        #expect(second == 0)
        #expect(try ModelContext(store).fetch(FetchDescriptor<WaterEntry>()).count == 1)
    }
}
