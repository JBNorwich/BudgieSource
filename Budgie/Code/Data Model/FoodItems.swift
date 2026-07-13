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
}

struct FoodQuantity: Codable {
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
    }
}

/// Actor to act on the FoodItem database.
@ModelActor
actor FoodItemActor {
    /// Inserts a new food item and saves.
    func insert(_ item: FoodItem) {
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

    /// Edits an existing item. Serving/calorie changes affect FUTURE logs only — past entries keep their stamped calories and macros. Name and manufacturer changes DO propagate to past linked entries, so a rename (or filling in a manufacturer) keeps already-logged items consistent.
    func update(id: UUID, name: String, manufacturer: String?, quantities: [FoodQuantity]) {
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.id == id })
        guard let item = (try? modelContext.fetch(descriptor))?.first else { return }
        item.name = name
        item.manufacturer = manufacturer
        item.quantities = quantities
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
}
