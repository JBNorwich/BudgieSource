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

import Foundation
import SwiftData
#if !os(macOS)
import HealthKit
#endif
import AppIntents

@Model final class Meal {
    private(set) var id: UUID = UUID()
    var mealUUID: UUID = UUID()
    /// The title of the meal
    var name: String = "Meal"
    /// Absolute order in the list of meals.
    var order: Int = 0
    /// Percentage of the budget allocated to this meal, if that feature is turned on. 0 is unallocated.
    var budgetPercent: Double = 0
    
    init(name: String, order: Int) {
        self.name = name.isEmpty ? "Unnamed meal" : name
        self.order = order
    }
    
    var syncNonce: Int = 0
}


extension Meal {
    /// Rebuilds a meal from a backup, keeping its identity so entry links and re-imports stay stable.
    convenience init(restoring dto: MealDTO) {
        self.init(name: dto.name, order: dto.order)
        self.id = dto.id
        self.mealUUID = dto.mealUUID
        self.budgetPercent = dto.budgetPercent
        self.syncNonce = dto.syncNonce
    }
}

/// SwiftData class for individual food entries.
@Model
final class CalorieEntry {
    private(set) var id: UUID = UUID()
    /// The date and time of the calorie entry.
    var date: Date = Date()
    /// The number of calories, as an integer.
    var calories: Int = 0
    /// Optional variable which describes what the food is. Budgie Diet will unwrap this to "Quick calories" if left blank or as nil.
    var narrative: String?
    /// Boolean that indicates whether the entry is in HealthKit.
    var isInHK: Bool = false
    /// The UUID of the matching entry in HealthKit.
    var healthKitUUID: UUID?
    /// Indicates whether this CalorieEntry is a real one, or a dummy one for display purposes.
    var realEntry: Bool = true
    /// The mealUUID of the meal which this food is allocated to.
    var meal: UUID = UUID()
    /// Synchronisation lever, in case of any sync issues.
    var syncNonce: Int = 0
    /// The UUID of the food item in the database.
    var foodItem: UUID?
    /// The manufacturer of the food, stamped at log time for display.
    var manufacturer: String?
    /// The serving this entry was logged with
    var servingUnit: FoodQuantityType?
    /// The serving quantity this entry was logged with
    var servingAmount: Double?
    /// The amount of protein in this serving.
    var protein: Double?
    /// The amount of fat in this serving.
    var fat: Double?
    /// The amount of carbs in this serving.
    var carbs: Double?

    
    init(date: Date, calories: Int, narrative: String?, mealUUID: UUID, isInHK: Bool, healthKitUUID: UUID?, item: UUID? = nil, manufacturer: String? = nil, unit: FoodQuantityType? = nil, servings: Double? = nil, protein: Double? = nil, fat: Double? = nil, carbs: Double? = nil) {
        self.date = date
        self.calories = calories
        self.narrative = narrative
        self.isInHK = isInHK
        self.realEntry = true
        self.meal = mealUUID
        self.healthKitUUID = isInHK ? healthKitUUID : nil
        self.isInHK = self.healthKitUUID != nil
        self.foodItem = item
        self.servingUnit = unit
        self.servingAmount = servings
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.manufacturer = manufacturer
    }
}

extension CalorieEntry {
    /// Whether this entry has a stamped serving to rescale — i.e. it was logged from a saved food
    /// OR a bundled generic (which has no `foodItem` link). Quick calorie entries have no serving.
    var isFoodEntry: Bool {
        servingUnit != nil && (servingAmount ?? 0) > 0
    }
    
    /// Whether this entry was logged from a bundled generic (a stamped serving but no saved-food link),
    /// as opposed to a user-created saved food or a plain quick entry.
    var isGenericFood: Bool {
        foodItem == nil && isFoodEntry
    }

    /// Rescales the stamped calories/macros to a new serving amount, kept proportional to the
    /// original stamp. nil when there's no serving to scale from (a quick / legacy entry).
    func rescaled(toAmount newAmount: Double) -> (calories: Int, protein: Double?, fat: Double?, carbs: Double?)? {
        guard let oldAmount = servingAmount, oldAmount > 0 else { return nil }
        let factor = newAmount / oldAmount
        return (
            calories: Int((Double(calories) * factor).rounded()),
            protein: protein.map { $0 * factor },
            fat: fat.map { $0 * factor },
            carbs: carbs.map { $0 * factor }
        )
    }
}

/// Actor to act on the CalorieEntry database.
@ModelActor
actor CalorieActor {
    func fetchCalsBetween(from: Date, to: Date) async -> [CalorieEntry] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let descriptor = FetchDescriptor<CalorieEntry>(
            predicate: #Predicate<CalorieEntry> { $0.date > from && $0.date < to }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchCalsForMeal(_ meal: Meal?) async -> [CalorieEntry] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        var searchPredicate: Predicate<CalorieEntry>
        if meal != nil {
            let mealUUID = meal!.mealUUID
            searchPredicate = #Predicate<CalorieEntry> { entry in
                entry.meal == mealUUID
            }
        } else {
            searchPredicate = #Predicate<CalorieEntry> { _ in true }
        }
        var descriptor = FetchDescriptor<CalorieEntry>(predicate: searchPredicate, sortBy: [SortDescriptor(\CalorieEntry.date, order: .reverse)])
        descriptor.fetchLimit = 100
        
        guard let results = try? modelContext.fetch(descriptor) else { return [] }
        var seenKeys = Set<String>()
        return results.filter { entry in
            guard let narrative = entry.narrative else { return true }
            return seenKeys.insert("\(narrative)|\(entry.calories)").inserted
        }
    }
    
    func searchCals(term: String, meal: UUID?, limit: Int = 50) async -> [CalorieEntry] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let predicate: Predicate<CalorieEntry>
        if let meal {
            predicate = #Predicate { $0.meal == meal && ($0.narrative?.localizedStandardContains(term) ?? false) }
        } else {
            predicate = #Predicate { $0.narrative?.localizedStandardContains(term) ?? false }
        }
        var descriptor = FetchDescriptor<CalorieEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        guard let results = try? modelContext.fetch(descriptor) else { return [] }

        // Same dedup as fetchCalsForMeal.
        var seen = Set<String>()
        return results.filter { entry in
            guard let n = entry.narrative else { return true }
            return seen.insert("\(n)|\(entry.calories)").inserted
        }
    }
    
    func insertNewCals(object: CalorieEntry)
    {

        do {
            modelContext.insert(object)
            try modelContext.save()
        } catch {
            print("Calorie insertion error: \(error)")
        }
    }
    
    func getListOfMeals() -> [Meal] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        do {
            let returns = try modelContext.fetch(FetchDescriptor<Meal>())
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

        do {
            modelContext.insert(breakfast)
            modelContext.insert(lunch)
            modelContext.insert(dinner)
            modelContext.insert(snacks)
            try modelContext.save()
        } catch {
            print("Error setting up meals: \(error)")
        }
    }
    
    func cleansedMealList(data: [CalorieEntry]) -> [Meal] {
        let usedMealUUIDs = Set(data.map(\.meal))
        return getListOfMeals()
            .filter { usedMealUUIDs.contains($0.mealUUID) }
            .sorted { $0.order < $1.order }
    }
    
    func getMealUUIDbyName(name: String) async -> UUID? {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate<Meal> { $0.name == name })
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.first?.mealUUID
    }
    
    func updateCalories(entry: CalorieEntry, calories: Int, narrative: String?, date: Date, meal: UUID, protein: Double? = nil, fat: Double? = nil, carbs: Double? = nil) async {
        #if !os(macOS)
        // HK can't be updated in place — delete the old sample, then write a fresh one.
        if entry.isInHK, let oldUUID = entry.healthKitUUID {
            await dataStore.deleteHKSample(uuid: oldUUID, type: eatenQuantityType)
            await dataStore.deleteMacroSamples(groupUUID: oldUUID)
        }
        let newUUID = entry.isInHK ? await dataStore.saveHKSample(value: Double(calories), unit: .kilocalorie(), type: eatenQuantityType, date: date) : nil
        if let newUUID { await dataStore.writeMacroSamples(groupUUID: newUUID, protein: protein, fat: fat, carbs: carbs, date: date) }
        #endif
        
        // SwiftData, unlike HK, can just be mutated — this preserves the entry's identity.
        entry.calories = calories
        entry.narrative = (narrative?.isEmpty ?? true) ? "Quick calories" : narrative!
        entry.date = date
        entry.meal = meal
        entry.protein = protein
        entry.fat = fat
        entry.carbs = carbs
        
        #if !os(macOS)
        entry.isInHK = newUUID != nil
        entry.healthKitUUID = newUUID
        #endif
        
        do {
            try modelContext.save()
        } catch {
            // Not recoverable.
        }
    }
    
    /// Updates a food-linked entry, writing recomputed calories/macros (and possibly a new serving unit)
    /// so the entry stays internally consistent. HealthKit's calorie sample is rewritten, as in updateCalories.
    func updateFoodEntry(entry: CalorieEntry, calories: Int, servingUnit: FoodQuantityType?, servingAmount: Double, protein: Double?, fat: Double?, carbs: Double?, date: Date, meal: UUID) async {
        #if !os(macOS)
        if entry.isInHK, let oldUUID = entry.healthKitUUID {
            await dataStore.deleteHKSample(uuid: oldUUID, type: eatenQuantityType)
            await dataStore.deleteMacroSamples(groupUUID: oldUUID)
        }
        let newUUID = entry.isInHK ? await dataStore.saveHKSample(value: Double(calories), unit: .kilocalorie(), type: eatenQuantityType, date: date) : nil
        if let newUUID { await dataStore.writeMacroSamples(groupUUID: newUUID, protein: protein, fat: fat, carbs: carbs, date: date) }
        #endif

        entry.calories = calories
        entry.servingUnit = servingUnit
        entry.servingAmount = servingAmount
        entry.protein = protein
        entry.fat = fat
        entry.carbs = carbs
        entry.date = date
        entry.meal = meal

        #if !os(macOS)
        entry.isInHK = newUUID != nil
        entry.healthKitUUID = newUUID
        #endif

        do {
            try modelContext.save()
        } catch {
            // Not recoverable.
        }
    }
    
    func deleteEntries(objects: [CalorieEntry]) async {
        for object in objects {
            #if !os(macOS)
            if object.isInHK, let hkUUID = object.healthKitUUID {
                await dataStore.deleteHKSample(uuid: hkUUID, type: eatenQuantityType)
                await dataStore.deleteMacroSamples(groupUUID: hkUUID)
            }
            #endif
            modelContext.delete(object)
        }
        do {
            try modelContext.save()
        } catch {
            // Not recoverable.
        }
    }
    
    /// Adds a new meal, placed after the current highest-ordered meal.
    func addMeal(name: String) {
        let nextOrder = (getListOfMeals().map(\.order).max() ?? -1) + 1
        let meal = Meal(name: name.trimmingCharacters(in: .whitespacesAndNewlines), order: nextOrder)
        modelContext.insert(meal)
        do { try modelContext.save() } catch { print("Meal insertion error: \(error)") }
    }
    
    /// Renames the meal identified by `mealUUID`. Empty names fall back to "Unnamed meal".
    func renameMeal(mealUUID: UUID, newName: String) {
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate<Meal> { $0.mealUUID == mealUUID })
        guard let meal = (try? modelContext.fetch(descriptor))?.first else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        meal.name = trimmed.isEmpty ? "Unnamed meal" : trimmed
        do { try modelContext.save() } catch { print("Meal rename error: \(error)") }
    }
    
    /// Persists a new display order. `orderedUUIDs` lists the meal UUIDs in the desired order.
    func reorderMeals(orderedUUIDs: [UUID]) {
        let meals = getListOfMeals()
        for (index, uuid) in orderedUUIDs.enumerated() {
            meals.first(where: { $0.mealUUID == uuid })?.order = index
        }
        do { try modelContext.save() } catch { print("Meal reorder error: \(error)") }
    }
    
    /// Deletes a meal, first moving every CalorieEntry assigned to it onto `reassignTo`.
    /// `protectedUUID` (the Snacks/Other meal) can never be deleted — the call is a no-op if it matches.
    func deleteMeal(mealUUID: UUID, reassignTo: UUID, protectedUUID: UUID?) {
        guard mealUUID != reassignTo else { return }
        guard mealUUID != protectedUUID else { return }

        // Move all entries off the doomed meal. Meal assignment is a Budgie Diet-only concept,
        // so there is nothing to update in HealthKit here.
        let entryDescriptor = FetchDescriptor<CalorieEntry>(predicate: #Predicate<CalorieEntry> { $0.meal == mealUUID })
        let entries = (try? modelContext.fetch(entryDescriptor)) ?? []
        for entry in entries { entry.meal = reassignTo }

        // Delete the meal itself.
        let mealDescriptor = FetchDescriptor<Meal>(predicate: #Predicate<Meal> { $0.mealUUID == mealUUID })
        if let meal = (try? modelContext.fetch(mealDescriptor))?.first {
            modelContext.delete(meal)
        }

        do { try modelContext.save() } catch { print("Meal deletion error: \(error)") }
    }
    
    /// Writes per-meal budget percentages. Values are clamped to 0...100.
    func setMealAllocations(_ allocations: [UUID: Double]) {
        let meals = getListOfMeals()
        for meal in meals {
            if let pct = allocations[meal.mealUUID] {
                meal.budgetPercent = max(0, min(100, pct))
            }
        }
        do { try modelContext.save() } catch { print("Allocation save error: \(error)") }
    }
    
    /// Merges meals that share a name (e.g. duplicates created when two devices both seeded the defaults before CloudKit synced). Keeps one copy of each name - preferring `preferredSurvivor` (the stored Snacks/Other UUID), then the lowest order - moves the duplicates' entries across, and deletes the rest.
    func dedupeMeals(preferredSurvivor: UUID?) {
        let meals = getListOfMeals().sorted {
            if $0.mealUUID == preferredSurvivor { return true }
            if $1.mealUUID == preferredSurvivor { return false }
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.mealUUID.uuidString < $1.mealUUID.uuidString   // stable tie-break across devices
        }
        var keptByName: [String: Meal] = [:]
        var changed = false
        for meal in meals {
            if let survivor = keptByName[meal.name] {
                let doomedUUID = meal.mealUUID
                let survivorUUID = survivor.mealUUID
                let descriptor = FetchDescriptor<CalorieEntry>(predicate: #Predicate<CalorieEntry> { $0.meal == doomedUUID })
                for entry in (try? modelContext.fetch(descriptor)) ?? [] { entry.meal = survivorUUID }
                modelContext.delete(meal)
                changed = true
            } else {
                keptByName[meal.name] = meal
            }
        }
        if changed {
            do { try modelContext.save() } catch { print("Meal dedupe error: \(error)") }
        }
    }
    
    /// Records the HealthKit sample UUID for an entry mirrored during reconciliation.
    func markCalorieMirrored(entryID: UUID, healthKitUUID: UUID) {
        let descriptor = FetchDescriptor<CalorieEntry>(predicate: #Predicate { $0.id == entryID })
        guard let entry = (try? modelContext.fetch(descriptor))?.first else { return }
        entry.healthKitUUID = healthKitUUID
        entry.isInHK = true
        try? modelContext.save()
    }
    
    /// Links existing quick entries matching a newly-saved food (case-insensitive narrative + exact calories, not already linked) to it, stamping a 1-serving portion and the food's manufacturer — same rule as the migration, so saving a food retroactively groups past matching entries under it.
    func linkQuickEntries(toFood foodID: UUID, name: String, manufacturer: String?, quantity: FoodQuantity) {
        let calories = quantity.calories
        let descriptor = FetchDescriptor<CalorieEntry>(
            predicate: #Predicate { $0.foodItem == nil && $0.calories == calories && $0.realEntry == true }
        )
        let lowerName = name.lowercased()
        var changed = false
        for entry in (try? modelContext.fetch(descriptor)) ?? []
        where entry.servingUnit == nil && (entry.narrative ?? "").lowercased() == lowerName {
            entry.foodItem = foodID
            entry.servingUnit = quantity.type          // stamp the food's own unit, not always .portion
            entry.servingAmount = quantity.count        // one serving == its reference count
            entry.manufacturer = manufacturer
            changed = true
        }
        if changed {
            do { try modelContext.save() } catch { print("Link quick entries error: \(error)") }
        }
    }
    
    /// One-time migration for users coming from before 3.3: turns legacy quick-calorie entries into searchable FoodItems, linking each entry to its new food and stamping a "1 serving" portion. Entries keep their own calories/macros (the stamped source of truth). Idempotent: only touches real entries with no food link and no stamped serving, and reuses a matching FoodItem if one already exists, so a re-run or a second device won't duplicate.
    func migrateLegacyEntries() {
        // Predicate stays on simple types; the serving-unit (a Codable enum) is filtered in Swift.
        let descriptor = FetchDescriptor<CalorieEntry>(
            predicate: #Predicate { $0.foodItem == nil && $0.realEntry == true }
        )
        guard let candidates = try? modelContext.fetch(descriptor) else { return }
        let entries = candidates.filter { $0.servingUnit == nil }
        guard !entries.isEmpty else { return }

        // Reuse existing single-portion foods (from a partial prior run or another device) rather than
        // duplicating. Keyed on name + calories, so distinct calorie amounts stay distinct foods.
        var foodByKey: [String: FoodItem] = [:]
        for f in (try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? [] where f.quantities.count == 1 {
            if let cal = f.quantities.first?.calories {
                foodByKey[Self.migrationKey(name: f.name, calories: cal)] = f
            }
        }

        for entry in entries {
            // Leave genuinely unlabeled quick entries alone — they stay quick calories.
            let narrative = entry.narrative?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if narrative.isEmpty || narrative.caseInsensitiveCompare("Quick calories") == .orderedSame {
                continue
            }

            let key = Self.migrationKey(name: narrative, calories: entry.calories)
            let food: FoodItem
            if let existing = foodByKey[key] {
                food = existing
            } else {
                let quantity = FoodQuantity(type: .portion, count: 1, calories: entry.calories,
                                            servingName: "1 serving")
                food = FoodItem(name: narrative, manufacturer: nil, quantities: [quantity], source: .migration)
                modelContext.insert(food)
                foodByKey[key] = food
            }

            entry.foodItem = food.id
            entry.servingUnit = .portion
            entry.servingAmount = 1
        }

        do { try modelContext.save() } catch { print("Legacy migration error: \(error)") }
    }

    private static func migrationKey(name: String, calories: Int) -> String {
        "\(name.lowercased())|\(calories)"
    }

    /// Merges structurally-identical FoodItems (same name, manufacturer and servings), moving any linked entries onto one survivor and deleting the rest. Catches duplicates from two devices migrating or creating the same food before CloudKit reconciles. Distinct-calorie "same name" variants have a different signature and are deliberately NOT merged. Custom meals are excluded from merging: their `quantities` is a baked-in total, not their composition, so two differently-composed meals that happen to share a name and total would otherwise be wrongly collapsed into one. Any meal whose component pointed at a food that WAS merged away still gets repointed to the survivor, so a dedup elsewhere never leaves a meal referencing a deleted FoodItem.
    func dedupeFoods() {
        // Sort by a stable key so every device chooses the SAME survivor for a duplicate pair.
        // Otherwise two devices can each keep a different copy and delete the other's; after CloudKit
        // merges, both tombstones win and the food is lost (its entries survive on their own stamp).
        let foods = ((try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? [])
            .sorted { $0.id.uuidString < $1.id.uuidString }
        var survivors: [String: FoodItem] = [:]
        var remap: [UUID: UUID] = [:]   // doomed food id -> survivor id
        var changed = false

        for food in foods where food.source != .customMeal {
            let key = Self.foodSignature(food)
            if let survivor = survivors[key] {
                let doomedID = food.id
                let survivorID = survivor.id
                let entryDescriptor = FetchDescriptor<CalorieEntry>(predicate: #Predicate { $0.foodItem == doomedID })
                for entry in (try? modelContext.fetch(entryDescriptor)) ?? [] { entry.foodItem = survivorID }
                remap[doomedID] = survivorID
                modelContext.delete(food)
                changed = true
            } else {
                survivors[key] = food
            }
        }

        if !remap.isEmpty {
            for food in foods where !food.components.isEmpty {
                var componentsChanged = false
                food.components = food.components.map { component in
                    guard let survivorID = remap[component.foodItemID] else { return component }
                    componentsChanged = true
                    var updated = component
                    updated.foodItemID = survivorID
                    return updated
                }
                if componentsChanged { changed = true }
            }
        }

        if changed {
            do { try modelContext.save() } catch { print("Food dedupe error: \(error)") }
        }
    }

    private static func foodSignature(_ food: FoodItem) -> String {
        FoodSignature.make(name: food.name, manufacturer: food.manufacturer, quantities: food.quantities)
    }

    // MARK: - Backup / restore

    /// Snapshots the food domain (meals, foods and real entries) as Sendable DTOs for export.
    func exportFoodDomain() -> (meals: [MealDTO], foods: [FoodItemDTO], entries: [CalorieEntryDTO]) {
        let meals = (try? modelContext.fetch(FetchDescriptor<Meal>())) ?? []
        let foods = (try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? []
        let entries = ((try? modelContext.fetch(FetchDescriptor<CalorieEntry>())) ?? []).filter(\.realEntry)
        return (meals.map(MealDTO.init), foods.map(FoodItemDTO.init), entries.map(CalorieEntryDTO.init))
    }

    /// Deletes every meal, food and calorie entry for a Replace import. HealthKit samples are left in place: restored entries keep their sample UUIDs and re-link via the reconciler, so clearing HK here would only strand data Apple Health legitimately owns.
    func wipeFoodDomain() {
        for entry in (try? modelContext.fetch(FetchDescriptor<CalorieEntry>())) ?? [] { modelContext.delete(entry) }
        for meal in (try? modelContext.fetch(FetchDescriptor<Meal>())) ?? [] { modelContext.delete(meal) }
        for food in (try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? [] { modelContext.delete(food) }
        do { try modelContext.save() } catch { print("Backup wipe error: \(error)") }
    }

    /// Inserts backed-up meals, foods and entries. In merge mode, rows whose identifier already exists are skipped so re-importing the same file is idempotent; a Replace has wiped first, so nothing collides. Returns how many of each were actually inserted.
    @discardableResult
    func importFoodDomain(meals: [MealDTO], foods: [FoodItemDTO], entries: [CalorieEntryDTO], merge: Bool)
    -> (meals: Int, foods: Int, entries: Int) {
        let mealUUIDs = merge ? Set(((try? modelContext.fetch(FetchDescriptor<Meal>())) ?? []).map(\.mealUUID)) : []
        let foodIDs = merge ? Set(((try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? []).map(\.id)) : []
        let entryIDs = merge ? Set(((try? modelContext.fetch(FetchDescriptor<CalorieEntry>())) ?? []).map(\.id)) : []

        var mealCount = 0, foodCount = 0, entryCount = 0
        for dto in meals where !mealUUIDs.contains(dto.mealUUID) { modelContext.insert(Meal(restoring: dto)); mealCount += 1 }
        for dto in foods where !foodIDs.contains(dto.id) { modelContext.insert(FoodItem(restoring: dto)); foodCount += 1 }
        for dto in entries where !entryIDs.contains(dto.id) { modelContext.insert(CalorieEntry(restoring: dto)); entryCount += 1 }
        do { try modelContext.save() } catch { print("Backup import error: \(error)") }
        return (mealCount, foodCount, entryCount)
    }
    
    /// Re-labels the entries logged from a food after it's renamed/re-manufacturered. Kept on
    /// CalorieActor (not FoodItemActor) so the change lands in the same context the app reads entries
    /// through — otherwise the Today screen shows stale names. Calories/macros are the entry's own
    /// stamped source of truth and are left untouched.
    func relabelEntries(forFood id: UUID, name: String, manufacturer: String?) {
        let descriptor = FetchDescriptor<CalorieEntry>(predicate: #Predicate { $0.foodItem == id })
        var changed = false
        for entry in (try? modelContext.fetch(descriptor)) ?? [] {
            entry.narrative = name
            entry.manufacturer = manufacturer
            changed = true
        }
        if changed {
            do { try modelContext.save() } catch { print("Relabel entries error: \(error)") }
        }
    }
    
    /// Non-empty manufacturer names the user has typed on logged entries.
    func manufacturers() -> [String] {
        let all = (try? modelContext.fetch(FetchDescriptor<CalorieEntry>())) ?? []
        return all.compactMap(\.manufacturer).filter { !$0.isEmpty }
    }
}

extension CalorieEntry {
    /// Rebuilds an entry from a backup. The HealthKit link is preserved deliberately: on a device
    /// whose Health data survived it re-attaches, and where it didn't the reconciler leaves the
    /// dangling UUID alone rather than pushing a duplicate sample.
    convenience init(restoring dto: CalorieEntryDTO) {
        self.init(date: dto.date, calories: dto.calories, narrative: dto.narrative,
                  mealUUID: dto.meal, isInHK: false, healthKitUUID: nil,
                  item: dto.foodItem, manufacturer: dto.manufacturer,
                  unit: dto.servingUnit, servings: dto.servingAmount,
                  protein: dto.protein, fat: dto.fat, carbs: dto.carbs)
        self.id = dto.id
        self.healthKitUUID = dto.healthKitUUID
        self.isInHK = dto.isInHK
        self.syncNonce = dto.syncNonce
    }
}
