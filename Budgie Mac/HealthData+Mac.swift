// Copyright 2026 Joseph Baldwin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of
// the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
// OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#if os(macOS)
import Foundation

extension HealthData {
    /// Logs food on the Mac — no HealthKit. The entry is written SwiftData-only with `isInHK == false`; the iPhone mirrors it into HealthKit when it next reconciles.
    func addCalories(calories: Int, narrative: String?, date: Date, meal: UUID, manufacturer: String? = nil, protein: Double? = nil, fat: Double? = nil, carbs: Double? = nil) async {
        let logNarrative = (narrative?.isEmpty ?? true) ? "Quick calories" : narrative!
        let entry = CalorieEntry(date: date, calories: calories, narrative: logNarrative, mealUUID: meal, isInHK: false, healthKitUUID: nil, manufacturer: manufacturer, protein: protein, fat: fat, carbs: carbs)
        await calorieActor.insertNewCals(object: entry)
    }
    
    /// Mac equivalent of `addFoodEntry` — SwiftData only, no HealthKit. The iPhone mirrors it later.
    func addFoodEntry(foodItemID: UUID?, name: String, manufacturer: String? = nil, quantity: FoodQuantity, servings: Double, date: Date, meal: UUID) async {
        guard servings > 0 else { return }
        let totals = quantity.totals(servings: servings)
        let entry = CalorieEntry(date: date,
                                 calories: totals.calories,
                                 narrative: name,
                                 mealUUID: meal,
                                 isInHK: false,
                                 healthKitUUID: nil,
                                 item: foodItemID,
                                 manufacturer: manufacturer,
                                 unit: quantity.type,
                                 servings: totals.amount,
                                 protein: totals.protein,
                                 fat: totals.fat,
                                 carbs: totals.carbs)
        await calorieActor.insertNewCals(object: entry)
    }

    /// Logs water on the Mac, SwiftData-only, for the iPhone to mirror later.
    func addWater(amount: Int, datetime: Date) async {
        await waterActor.addWater(object: WaterEntry(quantity: amount, healthKitUUID: nil, date: datetime))
    }

    /// The Mac equivalent of `updateLump`: no HealthKit, so the budget comes from the iPhone's snapshot and everything else is read straight from the shared SwiftData store.
    @MainActor func updateLump(todayLump: TodayLump, reloadWidgets: Bool = false, publishSnapshot: Bool = true) async {
        let todayStart = getStartOfDay(date: Date())
        let todayEnd = getMidnightOnDayAfter(date: todayStart)

        // Food today — Budgie's own entries only. The Mac can't see food logged in other apps'
        // HealthKit data; that's the known, accepted limitation.
        // Fan out the three independent fetches concurrently, mirroring the shared updateLump.
        async let foodListTask = calorieActor.fetchCalsBetween(from: todayStart, to: todayEnd)
        async let allMealsTask = calorieActor.getListOfMeals()
        async let waterTask = waterActor.getTotalOnDate(date: todayStart)

        let foodList = await foodListTask
        todayLump.foodList = foodList
        todayLump.healthKitCalories = settingsObj.snapShotHKCalories
        todayLump.eatenCalories = foodList.reduce(0) { $0 + $1.calories } + settingsObj.snapShotHKCalories
        // Macros today — own entries plus the iPhone's snapshot of other-app macros (no HealthKit here).
        todayLump.eatenProtein = Int(foodList.reduce(0.0) { $0 + ($1.protein ?? 0) }.rounded()) + settingsObj.snapShotHKProtein
        todayLump.eatenFat     = Int(foodList.reduce(0.0) { $0 + ($1.fat ?? 0) }.rounded()) + settingsObj.snapShotHKFat
        todayLump.eatenCarbs   = Int(foodList.reduce(0.0) { $0 + ($1.carbs ?? 0) }.rounded()) + settingsObj.snapShotHKCarbs
        todayLump.allMeals = await allMealsTask
        todayLump.cleansedMealList = await calorieActor.cleansedMealList(data: foodList)
        todayLump.mealTotalList = [:]
        for meal in todayLump.cleansedMealList {
            todayLump.mealTotalList[meal.mealUUID] =
                foodList.filter { $0.meal == meal.mealUUID }.reduce(0) { $0 + $1.calories }
        }

        // Water today.
        todayLump.waterToday = await waterTask + settingsObj.snapShotHKWater

        // Budget — taken from the iPhone's published snapshot, not recomputed.
        todayLump.applyBudgetSnapshot(budget: settingsObj.snapshotBudget,
                                      atCap: settingsObj.snapshotAtCap,
                                      atMin: settingsObj.snapshotAtMin)
        todayLump.activeCalories = settingsObj.snapshotActiveCalories
        todayLump.basalCalories = settingsObj.snapshotBasalCalories
        todayLump.projectedBasal = settingsObj.snapshotProjectedBasal
        todayLump.projectedActive = settingsObj.snapshotProjectedActive

        todayLump.lastUpdate = Date()
    }
}
#endif
