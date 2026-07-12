//
//  CatalogueTests.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 12/07/2026.
//


import Testing
import Foundation
@testable import Budgie_Diet

struct CatalogueTests {

    @Test func catalogueLoadsFromBundle() {
        // Canary: this fails loudly if generic_foods.json isn't in the app's Copy Bundle Resources,
        // or if its JSON stops decoding. (Tests are host-loaded, so Bundle.main is the app bundle.)
        #expect(FoodCatalogue.shared.foods.count > 0)
    }

    @Test func everyLoadedFoodHasAtLeastOneServing() {
        // The loader drops any food with no mappable servings, so none should come through empty.
        #expect(FoodCatalogue.shared.foods.allSatisfy { !$0.quantities.isEmpty })
    }

    @Test func searchIsCaseInsensitiveAndFindsAKnownFood() throws {
        let catalogue = FoodCatalogue.shared
        let sample = try #require(catalogue.foods.first { !$0.name.isEmpty })
        // A real fragment of a real name, upper-cased to prove the search ignores case.
        let fragment = String(sample.name.prefix(4)).uppercased()
        #expect(catalogue.search(fragment).contains { $0.id == sample.id })
    }

    @Test func blankSearchReturnsNothing() {
        #expect(FoodCatalogue.shared.search("   ").isEmpty)
    }
}