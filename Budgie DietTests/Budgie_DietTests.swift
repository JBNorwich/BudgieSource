import Testing
import Foundation
@testable import Budgie_Diet

struct FoodQuantityTests {

    @Test func totalsScaleCaloriesMacrosAndAmount() {
        let quantity = FoodQuantity(type: .grams, count: 100, calories: 650,
                                    protein: 30, carbs: 40, fat: 20)
        let totals = quantity.totals(servings: 2.5)

        #expect(totals.calories == 1625)   // 650 × 2.5
        #expect(totals.amount == 250)      // 100 g × 2.5 = 250 g
        #expect(totals.protein == 75)
        #expect(totals.carbs == 100)
        #expect(totals.fat == 50)
    }

    @Test func totalsLeaveMissingMacrosNil() {
        let quantity = FoodQuantity(type: .portion, count: 1, calories: 200,
                                    protein: nil, carbs: nil, fat: nil)
        let totals = quantity.totals(servings: 3)

        #expect(totals.calories == 600)
        #expect(totals.amount == 3)
        #expect(totals.protein == nil)   // a missing macro stays missing, not zero
    }
    
    @Test func rescalingKeepsCaloriesAndMacrosProportional() {
        let entry = CalorieEntry(date: .now, calories: 1625, narrative: "Claude Kibble",
                                 mealUUID: UUID(), isInHK: false, healthKitUUID: nil,
                                 item: UUID(), unit: .grams, servings: 250,
                                 protein: 75, fat: 50, carbs: 100)
        let r = entry.rescaled(toAmount: 100)!   // 250 g → 100 g, ×0.4
        #expect(r.calories == 650)
        #expect(r.protein == 30)
        #expect(r.fat == 20)
        #expect(r.carbs == 40)
    }

    @Test func rescalingReturnsNilForNonFoodEntry() {
        let entry = CalorieEntry(date: .now, calories: 300, narrative: "Quick",
                                 mealUUID: UUID(), isInHK: false, healthKitUUID: nil)
        #expect(entry.rescaled(toAmount: 2) == nil)
    }
    
    @Test func totalsScaleLinearly() {
        let q = FoodQuantity(type: .grams, count: 100, calories: 200, protein: 10, carbs: 20, fat: 5)
        let t = q.totals(servings: 1.5)
        #expect(t.calories == 300)
        #expect(t.amount == 150)
        #expect(t.protein == 15)
    }

    @Test func rescaledKeepsProportionAndReturnsNilForQuickEntries() {
        let food = CalorieEntry(date: .now, calories: 200, narrative: "X", mealUUID: UUID(),
                                isInHK: false, healthKitUUID: nil, unit: .grams, servings: 100, protein: 10)
        let r = food.rescaled(toAmount: 50)
        #expect(r?.calories == 100)
        #expect(r?.protein == 5)

        let quick = CalorieEntry(date: .now, calories: 100, narrative: "Snack", mealUUID: UUID(),
                                 isInHK: false, healthKitUUID: nil)
        #expect(quick.rescaled(toAmount: 2) == nil)
        #expect(quick.isFoodEntry == false)
        #expect(quick.isGenericFood == false)
    }
}
