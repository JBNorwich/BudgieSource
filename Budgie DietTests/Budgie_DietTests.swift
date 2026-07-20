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

/// Deterministic coverage for weightActiveProjection's per-style branching. Expected values were
/// worked out independently of the function's own code, so a change to the maths — deliberate or
/// not — actually gets caught rather than the test just re-deriving whatever the code currently
/// does. `input`/`timeInput` are chosen so every intermediate fraction (0, 0.5 or 1) is exactly
/// representable in binary floating point, keeping results bit-exact and clear of any truncation
/// boundary.
struct WeightActiveProjectionTests {

    @Test func styleMinus2NeverWeightsDownRegardlessOfTimeOrActQuot() {
        // "Don't weight down" always returns the full input, at any time, ignoring actQuot.
        #expect(weightActiveProjection(input: 200, style: -2, timeInput: 0, actQuot: 1) == 200)
        #expect(weightActiveProjection(input: 200, style: -2, timeInput: 1440, actQuot: 0.1) == 200)
    }

    @Test func styleMinus1ForgivingRampsDownAcrossTheDay() {
        #expect(weightActiveProjection(input: 100, style: -1, timeInput: 720, actQuot: 0) == 96)

        // Before the 240-minute start time, weightTime clamps to 240 — every sub-threshold time
        // (including 0) should therefore produce the identical result.
        let clamped = [0, 1, 100, 239, 240].map {
            weightActiveProjection(input: 300, style: -1, timeInput: $0, actQuot: 1)
        }
        #expect(Set(clamped).count == 1)
        #expect(clamped.first == 299)

        // Past the clamp the ramp keeps moving, down to zero credit right at midnight.
        #expect(weightActiveProjection(input: 300, style: -1, timeInput: 720, actQuot: 1) == 290)
        #expect(weightActiveProjection(input: 300, style: -1, timeInput: 1440, actQuot: 1) == 0)
    }

    @Test func styleZeroDefaultHalvesInputAndSquaresTheRamp() {
        #expect(weightActiveProjection(input: 200, style: 0, timeInput: 660, actQuot: 1) == 75)
        // actQuot scales the result directly (unlike styles -2, -1 and 3, which ignore it).
        #expect(weightActiveProjection(input: 200, style: 0, timeInput: 660, actQuot: 0.5) == 37)
    }

    @Test func styleOneHarshQuartersInputAndLinearlyRamps() {
        #expect(weightActiveProjection(input: 400, style: 1, timeInput: 660, actQuot: 1) == 50)
    }

    @Test func styleTwoNeverProjectsAnything() {
        #expect(weightActiveProjection(input: 1000, style: 2, timeInput: 500, actQuot: 5) == 0)
    }

    @Test func styleThreeOldDefaultIgnoresActQuot() {
        #expect(weightActiveProjection(input: 800, style: 3, timeInput: 660, actQuot: 99) == 525)
    }

    @Test func unrecognisedStyleFallsBackToZero() {
        // Any style outside -2...3 silently behaves like "no projection" rather than crashing or
        // defaulting to the regular style — locking this in so a future style value doesn't quietly
        // change this fallback without a test noticing.
        #expect(weightActiveProjection(input: 999, style: 42, timeInput: 999, actQuot: 999) == 0)
    }

    @Test func resultNeverGoesNegative() {
        // A negative actQuot shouldn't happen via the app's own call site, but the function doesn't
        // guard against it — it must still floor at zero rather than returning a negative kcal figure.
        #expect(weightActiveProjection(input: 100, style: 0, timeInput: 660, actQuot: -1) == 0)
    }
}
