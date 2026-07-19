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

/// A bundled generic food (CoFID-derived), held only in memory — never persisted to SwiftData/CloudKit.
struct CatalogueFood: Identifiable {
    let id: UUID
    let name: String
    let manufacturer: String?
    let quantities: [FoodQuantity]
}

/// Read-only, in-memory catalogue. Loaded once at launch.
final class FoodCatalogue {
    static let shared = FoodCatalogue()
    let foods: [CatalogueFood]

    private init() { foods = Self.load() }

    private static func load() -> [CatalogueFood] {
        guard let url = Bundle.main.url(forResource: "generic_foods", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([CatalogueFoodDTO].self, from: data).compactMap { $0.toCatalogueFood() }
        } catch {
            print("Food catalogue decode error: \(error)")
            return []
        }
    }

    /// Every catalogue entry matching `term`, unlimited — the shared base for both public `search`
    /// overloads, so excluding duplicates always happens before either one applies its result cap.
    private func matches(_ term: String) -> [CatalogueFood] {
        let t = term.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return [] }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(t) }
    }

    func search(_ term: String, limit: Int = 50) -> [CatalogueFood] {
        Array(matches(term).prefix(limit))
    }
}

extension FoodCatalogue {
    /// Generic catalogue matches for `term`, with anything structurally identical to one of the
    /// caller's own saved foods removed — a shared name alone isn't enough to call it a duplicate.
    /// Excludes duplicates against the FULL match set before applying `limit`, so a search doesn't
    /// come back short just because some of the first `limit` raw matches happened to be duplicates.
    func search(_ term: String, excluding mine: [FoodItem], limit: Int = 50) -> [CatalogueFood] {
        let mineSignatures = Set(mine.map {
            FoodSignature.make(name: $0.name, manufacturer: $0.manufacturer, quantities: $0.quantities)
        })
        return Array(matches(term).filter {
            !mineSignatures.contains(FoodSignature.make(name: $0.name, manufacturer: $0.manufacturer, quantities: $0.quantities))
        }.prefix(limit))
    }
}

// MARK: - Bundled JSON schema (decoupled from the persisted model)

private struct CatalogueFoodDTO: Codable {
    let name: String
    let manufacturer: String?
    let servings: [ServingDTO]

    func toCatalogueFood() -> CatalogueFood? {
        let quantities = servings.compactMap { $0.toFoodQuantity() }
        guard !quantities.isEmpty else { return nil }   // skip foods with no mappable servings
        return CatalogueFood(id: UUID(), name: name, manufacturer: manufacturer, quantities: quantities)
    }
}

private struct ServingDTO: Codable {
    let unit: String            // "g", "ml", or "portion"
    let amount: Double          // reference amount: 100 for per-100g, 1 for a single portion
    let calories: Double           // calories for that reference amount
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let name: String?           // optional friendly label, e.g. "1 medium banana"

    func toFoodQuantity() -> FoodQuantity? {
        guard let type = ServingDTO.type(for: unit) else { return nil }
        return FoodQuantity(type: type, count: amount, calories: Int(calories.rounded()),
                                    protein: protein, carbs: carbs, fat: fat, servingName: name)
    }

    private static func type(for unit: String) -> FoodQuantityType? {
        switch unit.lowercased() {
        case "g", "gram", "grams":                        return .grams
        case "ml", "millilitre", "millilitres",
             "milliliter", "milliliters":                 return .millilitres
        case "portion", "serving", "unit":                return .portion
        default:                                          return nil   // unknown unit → serving dropped
        }
    }
}

/// A unified "food you can log" — either a saved FoodItem or a bundled generic.
struct PickedFood: Identifiable {
    let id: UUID
    let persistedID: UUID?    // FoodItem.id if saved; nil for a bundled generic
    let name: String
    let manufacturer: String?
    let quantities: [FoodQuantity]
    var isGeneric: Bool { persistedID == nil }
}

extension FoodItem {
    var asPicked: PickedFood {
        PickedFood(id: id, persistedID: id, name: name, manufacturer: manufacturer, quantities: quantities)
    }
}

extension CatalogueFood {
    var asPicked: PickedFood {
        PickedFood(id: id, persistedID: nil, name: name, manufacturer: manufacturer, quantities: quantities)
    }
}

/// A comparable fingerprint of a food's name, manufacturer and servings — used to recognise when two
/// records are truly the same food (e.g. a generic catalogue entry and a saved copy of it), rather
/// than just sharing a name. Shared by food dedup and by anything that needs to avoid presenting or
/// re-saving a duplicate of something already in the library.
enum FoodSignature {
    static func make(name: String, manufacturer: String?, quantities: [FoodQuantity]) -> String {
        let base = "\(name.lowercased())|\(manufacturer?.lowercased() ?? "")"
        let servings = quantities.map { "\($0.type.unitName)-\($0.count)-\($0.calories)" }.joined(separator: ",")
        return "\(base)|\(servings)"
    }
}
