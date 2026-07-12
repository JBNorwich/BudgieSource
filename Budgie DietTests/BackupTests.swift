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
