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

enum FoodQuantityType: Codable {
    case portion
    case grams
    case millilitres
}

enum FoodSource: Codable {
    case userInput
    case openFoodFacts
    case migration
    case customMeal
}

struct FoodQuantity: Codable {
    /// Stable identity for this specific serving, so a meal ingredient can reference exactly which
    /// serving was picked rather than matching by type alone (a food can have more than one serving
    /// of the same type, e.g. two `.portion` entries for "1 slice" and "1 loaf").
    var id: UUID = UUID()
    /// The type of quantity (e.g. per portion/grams).
    var type: FoodQuantityType
    /// The count of quantity that the quantity represents.
    var count: Double
    /// The calorie count per quantity.
    var calories: Int
    /// The protein value, in grams
    var protein: Double?
    /// The carb count, in grams.
    var carbs: Double?
    /// The fat quantity, in grams
    var fat: Double?
    /// Friendly label for a portion.
    var servingName: String?

    init(id: UUID = UUID(), type: FoodQuantityType, count: Double, calories: Int,
         protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil, servingName: String? = nil) {
        self.id = id
        self.type = type
        self.count = count
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingName = servingName
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, count, calories, protein, carbs, fat, servingName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try c.decode(FoodQuantityType.self, forKey: .type)
        count = try c.decode(Double.self, forKey: .count)
        calories = try c.decode(Int.self, forKey: .calories)
        protein = try c.decodeIfPresent(Double.self, forKey: .protein)
        carbs = try c.decodeIfPresent(Double.self, forKey: .carbs)
        fat = try c.decodeIfPresent(Double.self, forKey: .fat)
        servingName = try c.decodeIfPresent(String.self, forKey: .servingName)
    }
}

extension FoodQuantity {
    /// Scales this quantity's calories, macros and amount by a number of servings.
    /// Used both to stamp an entry at log time and to preview totals live in the UI.
    func totals(servings: Double) -> (calories: Int, protein: Double?, fat: Double?, carbs: Double?, amount: Double) {
        (
            calories: Int((Double(calories) * servings).rounded()),
            protein: protein.map { $0 * servings },
            fat: fat.map { $0 * servings },
            carbs: carbs.map { $0 * servings },
            amount: count * servings
        )
    }
}

extension FoodQuantityType {
    /// Short unit name for display, e.g. "g", "ml", "portion".
    var unitName: String {
        switch self {
        case .portion: return "portion"
        case .grams: return "g"
        case .millilitres: return "ml"
        }
    }
}

extension FoodQuantity {
    var label: String {
        if let servingName, !servingName.isEmpty { return servingName }
        switch type {
        case .portion: return count == 1 ? "1 portion" : "\(count.formatted()) portions"
        case .grams: return "\(count.formatted()) g"
        case .millilitres: return "\(count.formatted()) ml"
        }
    }
}

/// One ingredient of a custom meal: a reference to another saved FoodItem plus how much of one of
/// its servings goes into the meal. Deliberately a plain UUID reference (not a SwiftData relationship),
/// matching every other cross-model link in this app, so it stays CloudKit-sync-safe.
struct MealComponent: Codable, Identifiable {
    var id: UUID = UUID()
    var foodItemID: UUID
    var servingID: UUID = UUID()
    var servingUnit: FoodQuantityType
    var servingAmount: Double

    init(id: UUID = UUID(), foodItemID: UUID, servingID: UUID = UUID(),
         servingUnit: FoodQuantityType, servingAmount: Double) {
        self.id = id
        self.foodItemID = foodItemID
        self.servingID = servingID
        self.servingUnit = servingUnit
        self.servingAmount = servingAmount
    }

    private enum CodingKeys: String, CodingKey {
        case id, foodItemID, servingID, servingUnit, servingAmount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        foodItemID = try c.decode(UUID.self, forKey: .foodItemID)
        // Missing on components saved before per-serving matching existed — falls back to
        // totals(in:)'s type-based match below, same as those components behaved beforehand.
        servingID = try c.decodeIfPresent(UUID.self, forKey: .servingID) ?? UUID()
        servingUnit = try c.decode(FoodQuantityType.self, forKey: .servingUnit)
        servingAmount = try c.decode(Double.self, forKey: .servingAmount)
    }

    /// This component's contribution, resolved against the matching serving on its (already-fetched)
    /// food. Matches by the specific serving id first (disambiguates two servings of the same type,
    /// e.g. "1 slice" vs "1 loaf"); falls back to matching by type alone if that serving was since
    /// removed, so an edited food doesn't just vanish from the meal. Nil if neither matches.
    func totals(in food: FoodItem) -> (calories: Int, protein: Double?, fat: Double?, carbs: Double?)? {
        let quantity = food.quantities.first(where: { $0.id == servingID })
            ?? food.quantities.first(where: { $0.type == servingUnit })
        guard let quantity, quantity.count > 0 else { return nil }
        let t = quantity.totals(servings: servingAmount / quantity.count)
        return (t.calories, t.protein, t.fat, t.carbs)
    }
}

extension FoodItem {
    /// Bakes a custom meal's components into its own single "1 serving" FoodQuantity: sums every
    /// component's totals against its resolved food, then divides by the batch yield. Called whenever
    /// the meal editor saves — the result is what gets stored in `quantities` and is what the rest of
    /// the app (search, logging, Shortcuts) sees, so a custom meal behaves like any other food with one
    /// serving option everywhere outside the editor.
    static func mealQuantity(components: [MealComponent], resolvedFoods: [UUID: FoodItem],
                             batchYield: Double, servingName: String?) -> FoodQuantity {
        var calories = 0.0
        var protein: Double?, carbs: Double?, fat: Double?
        for component in components {
            guard let food = resolvedFoods[component.foodItemID], let t = component.totals(in: food) else { continue }
            calories += Double(t.calories)
            if let p = t.protein { protein = (protein ?? 0) + p }
            if let c = t.carbs { carbs = (carbs ?? 0) + c }
            if let f = t.fat { fat = (fat ?? 0) + f }
        }
        let yield = batchYield > 0 ? batchYield : 1
        return FoodQuantity(type: .portion, count: 1, calories: Int((calories / yield).rounded()),
                            protein: protein.map { $0 / yield }, carbs: carbs.map { $0 / yield },
                            fat: fat.map { $0 / yield }, servingName: servingName)
    }
}

@Model
final class FoodItem {
    private(set) var id: UUID = UUID()
    
    /// The name of the food. This isn't going to be optional, we just need to provide a default for SwiftData.
    var name: String = "No name input"
    /// The manufacturer of the food.
    var manufacturer: String?
    /// Where the input came from. Defaults to user input.
    var source: FoodSource = FoodSource.userInput
    /// The quantities of food that this item has available.
    var quantities: [FoodQuantity] = []
    /// Whether the user has archived the food or not.
    var archived = false
    /// The barcode number of the item.
    var barcode: String?
    /// The created date of the food.
    var dateCreated: Date = Date()
    /// Synchronisation lever in case of any sync issues down the line.
    var syncNonce: Int = 0
    /// The ingredients of a custom meal (source == .customMeal). Empty for every other food.
    var components: [MealComponent] = []
    /// How many servings a custom meal's components make. `quantities` always holds the per-serving
    /// total (components summed, then divided by this), so this only matters inside the meal editor.
    var batchYield: Double = 1

    init(name: String, manufacturer: String?, quantities: [FoodQuantity], source: FoodSource?) {
        self.name = name
        self.manufacturer = manufacturer
        self.quantities = quantities
        self.source = source ?? .userInput
    }
}

extension FoodItem {
    /// Rebuilds a saved food from a backup, keeping its id so linked entries and re-imports stay stable.
    convenience init(restoring dto: FoodItemDTO) {
        self.init(name: dto.name, manufacturer: dto.manufacturer, quantities: dto.quantities, source: dto.source)
        self.id = dto.id
        self.archived = dto.archived
        self.barcode = dto.barcode
        self.dateCreated = dto.dateCreated
        self.syncNonce = dto.syncNonce
        // Optional in the DTO so a backup written before custom meals existed still decodes: a
        // missing key just means "not a meal", which is exactly true of every food in such a backup.
        self.components = dto.components ?? []
        self.batchYield = dto.batchYield ?? 1
    }
}

/// Actor to act on the FoodItem database.
@ModelActor
actor FoodItemActor {
    /// A custom meal can't itself be used as an ingredient of another meal — enforced here, at the
    /// only place components are actually persisted, rather than relying on every caller (UI pickers,
    /// Shortcuts, backup restore) to have separately excluded meals from whatever list they built
    /// components from. A bad reference is dropped rather than rejecting the whole save, so a stray
    /// one (e.g. from a hand-edited or older-version backup) doesn't block saving the rest of the item.
    private func stripNestedMealComponents(_ components: [MealComponent]) -> [MealComponent] {
        let ids = Set(components.map(\.foodItemID))
        guard !ids.isEmpty else { return components }
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { ids.contains($0.id) })
        let referenced = (try? modelContext.fetch(descriptor)) ?? []
        let mealIDs = Set(referenced.filter { $0.source == .customMeal }.map(\.id))
        guard !mealIDs.isEmpty else { return components }
        return components.filter { !mealIDs.contains($0.foodItemID) }
    }

    /// Inserts a new food item and saves.
    func insert(_ item: FoodItem) {
        item.components = stripNestedMealComponents(item.components)
        modelContext.insert(item)
        do { try modelContext.save() } catch { print("FoodItem insertion error: \(error)") }
    }
    
    /// Persists an OpenFoodFacts import, or reuses a non-archived saved food with the same barcode instead of creating a duplicate, and returns it as a value type to log against. Stops the same product piling up copies when it's imported more than once.
    func importOFF(_ item: FoodItem) -> PickedFood {
        if let barcode = item.barcode, !barcode.isEmpty {
            let descriptor = FetchDescriptor<FoodItem>(
                predicate: #Predicate { $0.barcode == barcode && $0.archived == false })
            if let existing = (try? modelContext.fetch(descriptor))?.first { return existing.asPicked }
        }
        modelContext.insert(item)
        do { try modelContext.save() } catch { print("FoodItem insertion error: \(error)") }
        return item.asPicked
    }

    /// All food items, newest first. Archived items are excluded unless asked for.
    func fetchAll(includeArchived: Bool = false) -> [FoodItem] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let predicate: Predicate<FoodItem> = includeArchived
            ? #Predicate { _ in true }
            : #Predicate { $0.archived == false }
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Searches items by name or manufacturer. Archived items are excluded unless asked for.
    func search(term: String, includeArchived: Bool = false, limit: Int = 50) -> [FoodItem] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let predicate = #Predicate<FoodItem> { item in
            (includeArchived || item.archived == false) &&
            (item.name.localizedStandardContains(term) ||
             (item.manufacturer?.localizedStandardContains(term) ?? false))
        }
        var descriptor = FetchDescriptor<FoodItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Resolves a single item by its stable UUID — e.g. to open the food behind an entry's `foodItem` link.
    func fetch(id: UUID) -> FoodItem? {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor))?.first
    }

    /// Resolves multiple items by their stable UUIDs in one round trip — used to preload every
    /// ingredient of a custom meal at once instead of one fetch per ingredient.
    func fetch(ids: [UUID]) -> [FoodItem] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { ids.contains($0.id) })
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Edits an existing item. Serving/calorie changes affect FUTURE logs only — past entries keep their stamped calories and macros. Name and manufacturer changes DO propagate to past linked entries, so a rename (or filling in a manufacturer) keeps already-logged items consistent. `components`/`batchYield` only apply to custom meals; leave them `nil` to leave the item's existing values untouched, so a caller that doesn't know about meals (e.g. the ordinary food editor) can never wipe a meal's ingredients just by reaching an item it doesn't recognise as one.
    func update(id: UUID, name: String, manufacturer: String?, quantities: [FoodQuantity],
                components: [MealComponent]? = nil, batchYield: Double? = nil) {
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.id == id })
        guard let item = (try? modelContext.fetch(descriptor))?.first else { return }
        item.name = name
        item.manufacturer = manufacturer
        item.quantities = quantities
        if let components { item.components = stripNestedMealComponents(components) }
        if let batchYield { item.batchYield = batchYield }
        do { try modelContext.save() } catch { print("FoodItem update error: \(error)") }
    }

    /// Archives / unarchives — pulls it from pickers without disturbing any entries that reference it.
    func setArchived(id: UUID, archived: Bool) {
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.id == id })
        guard let item = (try? modelContext.fetch(descriptor))?.first else { return }
        item.archived = archived
        do { try modelContext.save() } catch { print("FoodItem archive error: \(error)") }
    }

    /// The serving options for a food, by id — used when editing an entry so the user can switch
    /// serving kind. Returns [] if the food no longer exists.
    func quantities(id: UUID) -> [FoodQuantity] {
        #if os(macOS)
        modelContext.rollback()
        #endif
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor))?.first?.quantities ?? []
    }
    
    /// Non-archived saved foods whose name matches exactly (case-insensitive). For the log-food intent.
    func picked(named name: String) -> [PickedFood] {
        let lower = name.lowercased()
        let all = (try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? []
        return all.filter { !$0.archived && $0.name.lowercased() == lower }.map(\.asPicked)
    }

    /// One saved food by its persistent id, as a value type. For the saved-food intent.
    func picked(id: UUID) -> PickedFood? {
        let d = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(d))?.first?.asPicked
    }

    /// Every non-archived saved food, for the Shortcuts food picker.
    func allPicked() -> [PickedFood] {
        ((try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? []).filter { !$0.archived }.map(\.asPicked)
    }
    
    /// Non-empty manufacturer names from saved foods (may repeat; HealthData folds them).
    func manufacturers() -> [String] {
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.manufacturer != nil })
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.compactMap(\.manufacturer).filter { !$0.isEmpty }
    }
}
