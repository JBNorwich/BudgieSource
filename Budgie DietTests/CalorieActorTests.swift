import Testing
import SwiftData
import Foundation
@testable import Budgie_Diet

@Suite(.serialized)
struct CalorieActorTests {
    /// Full-schema store: migration/dedup/backfill span CalorieEntry, FoodItem and Meal,
    /// so a single-model container would make those tests pass without testing anything.
    private func makeStore() throws -> ModelContainer {
        try ModelContainer(
            for: CalorieEntry.self, FoodItem.self, Meal.self, WaterEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func relabelEntriesUpdatesNarrativeAndManufacturerButNotCalories() async throws {
        let store = try makeStore()
        let ctx = ModelContext(store)
        let foodID = UUID()
        ctx.insert(CalorieEntry(date: .now, calories: 100, narrative: "Old", mealUUID: UUID(),
                                isInHK: false, healthKitUUID: nil, item: foodID, unit: .portion, servings: 1))
        try ctx.save()

        await CalorieActor(modelContainer: store).relabelEntries(forFood: foodID, name: "New", manufacturer: "Brand")

        let entry = try ModelContext(store).fetch(FetchDescriptor<CalorieEntry>()).first
        #expect(entry?.narrative == "New")
        #expect(entry?.manufacturer == "Brand")
        #expect(entry?.calories == 100)          // snapshot preserved
    }
    
    @Test func migrationConvertsLabelledEntriesAndIsIdempotent() async throws {
        let store = try makeStore()
        let ctx = ModelContext(store)
        let meal = UUID()
        ctx.insert(CalorieEntry(date: .now, calories: 250, narrative: "Flapjack", mealUUID: meal,
                                isInHK: false, healthKitUUID: nil))
        ctx.insert(CalorieEntry(date: .now, calories: 0, narrative: "Quick calories", mealUUID: meal,
                                isInHK: false, healthKitUUID: nil))
        try ctx.save()

        let actor = CalorieActor(modelContainer: store)
        await actor.migrateLegacyEntries()

        let check = ModelContext(store)
        let foods = try check.fetch(FetchDescriptor<FoodItem>())
        #expect(foods.count == 1)                       // one food, from the labelled entry
        #expect(foods.first?.name == "Flapjack")

        let entries = try check.fetch(FetchDescriptor<CalorieEntry>())
        let flapjack = entries.first { $0.narrative == "Flapjack" }
        #expect(flapjack?.foodItem != nil)
        #expect(flapjack?.servingUnit == .portion)
        #expect(flapjack?.servingAmount == 1)
        let quick = entries.first { $0.narrative == "Quick calories" }
        #expect(quick?.foodItem == nil)                 // blank / "Quick calories" left untouched

        await actor.migrateLegacyEntries()              // idempotent: second run adds nothing
        #expect(try ModelContext(store).fetch(FetchDescriptor<FoodItem>()).count == 1)
    }

    @Test func linkQuickEntriesStampsFoodPortionAndManufacturer() async throws {
        let store = try makeStore()
        let ctx = ModelContext(store)
        ctx.insert(CalorieEntry(date: .now, calories: 90, narrative: "protein bar", mealUUID: UUID(),
                                isInHK: false, healthKitUUID: nil))   // matches (case-insensitive)
        ctx.insert(CalorieEntry(date: .now, calories: 120, narrative: "protein bar", mealUUID: UUID(),
                                isInHK: false, healthKitUUID: nil))   // wrong calories → must be left alone
        try ctx.save()

        let foodID = UUID()
        await CalorieActor(modelContainer: store)
            .linkQuickEntries(toFood: foodID, name: "Protein Bar", manufacturer: "Acme", calories: 90)

        let entries = try ModelContext(store).fetch(FetchDescriptor<CalorieEntry>())
        let linked = entries.first { $0.calories == 90 }
        #expect(linked?.foodItem == foodID)
        #expect(linked?.manufacturer == "Acme")         // manufacturer stamped onto the past entry
        #expect(linked?.servingUnit == .portion)
        #expect(linked?.servingAmount == 1)

        let untouched = entries.first { $0.calories == 120 }
        #expect(untouched?.foodItem == nil)             // different calories → not linked
        #expect(untouched?.manufacturer == nil)
    }

    @Test func dedupeMergesIdenticalFoodsAndReassignsEntries() async throws {
        let store = try makeStore()
        let ctx = ModelContext(store)
        let q = [FoodQuantity(type: .portion, count: 1, calories: 100)]
        let a = FoodItem(name: "Egg", manufacturer: nil, quantities: q, source: .userInput)
        let b = FoodItem(name: "Egg", manufacturer: nil, quantities: q, source: .userInput)   // structural duplicate
        let c = FoodItem(name: "Egg", manufacturer: nil,
                         quantities: [FoodQuantity(type: .portion, count: 1, calories: 155)],
                         source: .userInput)                                                   // same name, different calories
        ctx.insert(a); ctx.insert(b); ctx.insert(c)
        ctx.insert(CalorieEntry(date: .now, calories: 100, narrative: "Egg", mealUUID: UUID(),
                                isInHK: false, healthKitUUID: nil, item: b.id, unit: .portion, servings: 1))
        try ctx.save()

        await CalorieActor(modelContainer: store).dedupeFoods()

        let foods = try ModelContext(store).fetch(FetchDescriptor<FoodItem>())
        #expect(foods.count == 2)                       // the two identical "Egg 100" merge; "Egg 155" stays

        let survivors = Set(foods.map(\.id))
        let entry = try ModelContext(store).fetch(FetchDescriptor<CalorieEntry>()).first
        #expect(entry?.foodItem != nil)
        #expect(survivors.contains(entry!.foodItem!))   // entry re-pointed at whichever "Egg 100" survived
    }

    @Test func dedupeMealsMergesSameNameAndReassignsEntries() async throws {
        let store = try makeStore()
        let ctx = ModelContext(store)
        let m1 = Meal(name: "Breakfast", order: 0)
        let m2 = Meal(name: "Breakfast", order: 1)      // duplicate name, e.g. two devices both seeded defaults
        ctx.insert(m1); ctx.insert(m2)
        ctx.insert(CalorieEntry(date: .now, calories: 200, narrative: "Toast", mealUUID: m2.mealUUID,
                                isInHK: false, healthKitUUID: nil))
        try ctx.save()

        await CalorieActor(modelContainer: store).dedupeMeals(preferredSurvivor: nil)

        let meals = try ModelContext(store).fetch(FetchDescriptor<Meal>())
        #expect(meals.count == 1)                       // the two "Breakfast" meals collapse to one
        let survivorUUID = meals.first!.mealUUID
        let entry = try ModelContext(store).fetch(FetchDescriptor<CalorieEntry>()).first
        #expect(entry?.meal == survivorUUID)            // entry moved onto the surviving meal
    }
}
