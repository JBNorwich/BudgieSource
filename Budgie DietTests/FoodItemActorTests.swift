//
//  FoodItemActorTests.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 10/07/2026.
//


import Testing
import SwiftData
@testable import Budgie_Diet

struct FoodItemActorTests {

    /// A throwaway in-memory store + actor for one test.
    private func makeActor() throws -> FoodItemActor {
        let container = try ModelContainer(
            for: FoodItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return FoodItemActor(modelContainer: container)
    }

    @Test func insertThenFetchByID() async throws {
        let actor = try makeActor()
        let item = FoodItem(name: "Claude Kibble", manufacturer: "Anthropic",
                            quantities: [FoodQuantity(type: .grams, count: 100, calories: 650,
                                                      protein: 30, carbs: 40, fat: 20)],
                            source: .userInput)
        let itemID = item.id            // read before handing it to the actor
        await actor.insert(item)

        let all = await actor.fetchAll()
        #expect(all.count == 1)

        let found = await actor.fetch(id: itemID)
        #expect(found?.name == "Claude Kibble")
        #expect(found?.manufacturer == "Anthropic")
    }

    @Test func archivedItemsAreHiddenByDefault() async throws {
        let actor = try makeActor()
        let item = FoodItem(name: "Old snack", manufacturer: nil, quantities: [], source: .userInput)
        let itemID = item.id
        await actor.insert(item)
        await actor.setArchived(id: itemID, archived: true)

        #expect(await actor.fetchAll().isEmpty)                       // hidden
        #expect(await actor.fetchAll(includeArchived: true).count == 1) // still there
    }

    @Test func updateWritesComponentsAndBatchYieldForCustomMeal() async throws {
        let actor = try makeActor()
        let ingredient = FoodItem(name: "Egg", manufacturer: nil,
                                  quantities: [FoodQuantity(type: .portion, count: 1, calories: 78)],
                                  source: .userInput)
        await actor.insert(ingredient)

        let meal = FoodItem(name: "Empty meal", manufacturer: nil, quantities: [], source: .customMeal)
        let mealID = meal.id
        await actor.insert(meal)

        let components = [MealComponent(foodItemID: ingredient.id, servingID: ingredient.quantities[0].id,
                                        servingUnit: .portion, servingAmount: 2)]
        await actor.update(id: mealID, name: "Two eggs", manufacturer: nil,
                           quantities: [FoodQuantity(type: .portion, count: 1, calories: 156)],
                           components: components, batchYield: 1)

        let updated = await actor.fetch(id: mealID)
        #expect(updated?.components.count == 1)
        #expect(updated?.components.first?.foodItemID == ingredient.id)
        #expect(updated?.components.first?.servingAmount == 2)
        #expect(updated?.batchYield == 1)
        #expect(updated?.quantities.first?.calories == 156)
    }

    @Test func updateWithoutComponentsLeavesEmptyComponentsEmptyForOrdinaryFoods() async throws {
        // FoodEditorView's existing call site never passes components/batchYield — confirms that
        // omitting them (which now means "leave unchanged", not "clear") doesn't disturb an
        // ordinary food's already-empty components.
        let actor = try makeActor()
        let food = FoodItem(name: "Bread", manufacturer: nil,
                            quantities: [FoodQuantity(type: .grams, count: 100, calories: 265)], source: .userInput)
        let foodID = food.id
        await actor.insert(food)

        await actor.update(id: foodID, name: "Bread", manufacturer: "Brand",
                           quantities: [FoodQuantity(type: .grams, count: 100, calories: 270)])

        let updated = await actor.fetch(id: foodID)
        #expect(updated?.components.isEmpty == true)
        #expect(updated?.batchYield == 1)
        #expect(updated?.manufacturer == "Brand")
        #expect(updated?.quantities.first?.calories == 270)
    }

    @Test func updateWithoutComponentsPreservesExistingMealIngredients() async throws {
        // A caller that doesn't know about meals (e.g. the ordinary food editor reaching a
        // custom meal it doesn't recognise as one) must never wipe the meal's ingredients just
        // by omitting components/batchYield — regression test for that data-loss bug.
        let actor = try makeActor()
        let ingredient = FoodItem(name: "Egg", manufacturer: nil,
                                  quantities: [FoodQuantity(type: .portion, count: 1, calories: 78)],
                                  source: .userInput)
        await actor.insert(ingredient)

        let meal = FoodItem(name: "Two eggs", manufacturer: nil,
                            quantities: [FoodQuantity(type: .portion, count: 1, calories: 156)],
                            source: .customMeal)
        meal.components = [MealComponent(foodItemID: ingredient.id, servingID: ingredient.quantities[0].id,
                                         servingUnit: .portion, servingAmount: 2)]
        meal.batchYield = 1
        let mealID = meal.id
        await actor.insert(meal)

        // Simulates FoodEditorView.save(), which never passes components/batchYield.
        await actor.update(id: mealID, name: "Two eggs", manufacturer: "Brand",
                           quantities: [FoodQuantity(type: .portion, count: 1, calories: 156)])

        let updated = await actor.fetch(id: mealID)
        #expect(updated?.manufacturer == "Brand")           // the field the caller did mean to change
        #expect(updated?.components.count == 1)             // ingredients untouched
        #expect(updated?.components.first?.foodItemID == ingredient.id)
        #expect(updated?.batchYield == 1)                   // batchYield untouched
    }

    @Test func insertStripsComponentsReferencingAnotherCustomMeal() async throws {
        // "No nesting" is a UI-only rule in the meal-ingredient picker — this confirms the model
        // layer also refuses to save a meal-of-meal reference, e.g. from a hand-edited backup.
        let actor = try makeActor()
        let innerMeal = FoodItem(name: "Inner meal", manufacturer: nil,
                                 quantities: [FoodQuantity(type: .portion, count: 1, calories: 100)],
                                 source: .customMeal)
        await actor.insert(innerMeal)

        let ingredient = FoodItem(name: "Toast", manufacturer: nil,
                                  quantities: [FoodQuantity(type: .portion, count: 1, calories: 80)],
                                  source: .userInput)
        await actor.insert(ingredient)

        let outerMeal = FoodItem(name: "Outer meal", manufacturer: nil,
                                 quantities: [FoodQuantity(type: .portion, count: 1, calories: 180)],
                                 source: .customMeal)
        outerMeal.components = [
            MealComponent(foodItemID: innerMeal.id, servingID: innerMeal.quantities[0].id,
                          servingUnit: .portion, servingAmount: 1),   // invalid: nests a meal
            MealComponent(foodItemID: ingredient.id, servingID: ingredient.quantities[0].id,
                          servingUnit: .portion, servingAmount: 1)    // valid
        ]
        let outerID = outerMeal.id
        await actor.insert(outerMeal)

        let saved = await actor.fetch(id: outerID)
        #expect(saved?.components.count == 1)
        #expect(saved?.components.first?.foodItemID == ingredient.id)
    }

    @Test func updateStripsComponentsReferencingAnotherCustomMeal() async throws {
        let actor = try makeActor()
        let innerMeal = FoodItem(name: "Inner meal", manufacturer: nil,
                                 quantities: [FoodQuantity(type: .portion, count: 1, calories: 100)],
                                 source: .customMeal)
        await actor.insert(innerMeal)

        let outerMeal = FoodItem(name: "Outer meal", manufacturer: nil, quantities: [], source: .customMeal)
        let outerID = outerMeal.id
        await actor.insert(outerMeal)

        await actor.update(id: outerID, name: "Outer meal", manufacturer: nil,
                           quantities: [FoodQuantity(type: .portion, count: 1, calories: 100)],
                           components: [MealComponent(foodItemID: innerMeal.id, servingID: innerMeal.quantities[0].id,
                                                      servingUnit: .portion, servingAmount: 1)],
                           batchYield: 1)

        let updated = await actor.fetch(id: outerID)
        #expect(updated?.components.isEmpty == true)
    }

    @Test func updateReplacesRatherThanMergesExistingComponents() async throws {
        let actor = try makeActor()
        let a = FoodItem(name: "A", manufacturer: nil,
                         quantities: [FoodQuantity(type: .portion, count: 1, calories: 50)], source: .userInput)
        let b = FoodItem(name: "B", manufacturer: nil,
                         quantities: [FoodQuantity(type: .portion, count: 1, calories: 50)], source: .userInput)
        await actor.insert(a); await actor.insert(b)

        let meal = FoodItem(name: "Meal", manufacturer: nil, quantities: [], source: .customMeal)
        meal.components = [MealComponent(foodItemID: a.id, servingID: a.quantities[0].id,
                                         servingUnit: .portion, servingAmount: 1)]
        let mealID = meal.id
        await actor.insert(meal)

        // Editing the meal to swap component A for component B should leave exactly B, not both.
        await actor.update(id: mealID, name: "Meal", manufacturer: nil,
                           quantities: [FoodQuantity(type: .portion, count: 1, calories: 50)],
                           components: [MealComponent(foodItemID: b.id, servingID: b.quantities[0].id,
                                                      servingUnit: .portion, servingAmount: 1)],
                           batchYield: 1)

        let updated = await actor.fetch(id: mealID)
        #expect(updated?.components.count == 1)
        #expect(updated?.components.first?.foodItemID == b.id)
    }
}
