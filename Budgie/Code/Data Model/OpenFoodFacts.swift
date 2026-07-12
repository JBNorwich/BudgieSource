//
//  OFFProduct.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 12/07/2026.
//


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

/// A single OpenFoodFacts product, reduced to what Budgie Diet needs and mapped onto its own model.
struct OFFProduct: Identifiable {
    let id: String
    let name: String
    let brand: String?
    let barcode: String?
    let quantities: [FoodQuantity]

    func toFoodItem() -> FoodItem {
        let food = FoodItem(name: name, manufacturer: brand, quantities: quantities, source: .openFoodFacts)
        food.barcode = barcode
        return food
    }
}

enum OpenFoodFacts {
    enum SearchError: Error { case rateLimited }

    /// Full-text product search. Sends only the search term. User-initiated, so low volume — but OFF caps search at 10 req/min/IP, which is why the UI only calls this on submit.
    static func search(term: String) async throws -> [OFFProduct] {
        var comps = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        comps.queryItems = [
            .init(name: "search_terms", value: term),
            .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"),
            .init(name: "json", value: "1"),
            .init(name: "sort_by", value: "unique_scans_n"),   // popularity — well-known products first
            .init(name: "page_size", value: "30"),
            .init(name: "fields", value: "product_name,brands,code,serving_size,serving_quantity,nutriments")
        ]

        var request = URLRequest(url: comps.url!)
        request.setValue("Budgie Diet/3.3 (https://github.com/JBNorwich/BudgieSource)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 { throw SearchError.rateLimited }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        let products = decoded.products.compactMap { $0.product?.toProduct() }
        return rank(products, for: term)
    }
    
    /// The legacy search matches loosely across all fields and doesn't rank. Keep only products whose
    /// name or brand actually contains the query, best matches first — cuts the ingredient/category noise.
    private static func rank(_ products: [OFFProduct], for term: String) -> [OFFProduct] {
        let tokens = term.lowercased().split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return products }
        return products
            .map { p -> (OFFProduct, Int) in
                let haystack = (p.name + " " + (p.brand ?? "")).lowercased()
                return (p, tokens.filter { haystack.contains($0) }.count)
            }
            .filter { $0.1 > 0 }          // must match at least one query word in name/brand
            .sorted { $0.1 > $1.1 }        // most words matched first
            .map { $0.0 }
    }
}

private struct SearchResponse: Decodable {
    let products: [LenientProduct]
}

/// Wraps each product so one malformed entry is skipped rather than failing the whole response.
private struct LenientProduct: Decodable {
    let product: ProductDTO?
    init(from decoder: Decoder) throws {
        product = try? ProductDTO(from: decoder)
    }
}

private struct ProductDTO: Decodable {
    let product_name: String?
    let brands: String?
    let code: String?
    let serving_size: String?
    let serving_quantity: FlexibleDouble?
    let nutriments: Nutriments?

    struct Nutriments: Decodable {
        let energyKcal100g: FlexibleDouble?
        let proteins100g: FlexibleDouble?
        let carbohydrates100g: FlexibleDouble?
        let fat100g: FlexibleDouble?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case proteins100g = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case fat100g = "fat_100g"
        }
    }

    func toProduct() -> OFFProduct? {
        guard let rawName = product_name?.trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty,
              let kcal100 = nutriments?.energyKcal100g?.value else { return nil } // skip products with no usable nutrition

        let per100 = FoodQuantity(type: .grams, count: 100, calories: Int(kcal100.rounded()),
                                 protein: nutriments?.proteins100g?.value,
                                 carbs: nutriments?.carbohydrates100g?.value,
                                 fat: nutriments?.fat100g?.value)

       var quantities: [FoodQuantity] = []
       if let grams = serving_quantity?.value, grams > 0 {
           let factor = grams / 100
           quantities.append(FoodQuantity(
               type: .portion, count: 1,
               calories: Int((kcal100 * factor).rounded()),
               protein: nutriments?.proteins100g?.value.map { $0 * factor },
               carbs: nutriments?.carbohydrates100g?.value.map { $0 * factor },
               fat: nutriments?.fat100g?.value.map { $0 * factor },
               servingName: (serving_size?.isEmpty ?? true) ? "1 serving" : serving_size))
       }
       quantities.append(per100)

        let brand = brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces)
        let bc = (code?.isEmpty ?? true) ? nil : code
        return OFFProduct(id: bc ?? UUID().uuidString,
                          name: rawName,
                          brand: (brand?.isEmpty ?? true) ? nil : brand,
                          barcode: bc,
                          quantities: quantities)
    }
}

/// OFF sometimes returns numbers as strings (e.g. serving_quantity). Decode either.
private struct FlexibleDouble: Decodable {
    let value: Double?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self) { value = Double(s) }
        else { value = nil }
    }
}
