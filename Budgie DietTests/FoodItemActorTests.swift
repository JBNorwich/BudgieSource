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
}
