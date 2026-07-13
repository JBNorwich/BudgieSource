//
//  OpenFoodFactsSheet.swift
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

import SwiftUI

struct OpenFoodFactsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchTerm: String
    @State private var showingConsent: Bool
    /// Called when the user picks an OFF result — imports it and hands it back to the add form. (Wired in step 2.)
    var onImport: (PickedFood) -> Void
    
    @State private var results: [OFFProduct] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    init(term: String, onImport: @escaping (PickedFood) -> Void) {
        _searchTerm = State(initialValue: term)
        _showingConsent = State(initialValue: !settingsObj.offSearchConsented)
        self.onImport = onImport
    }

    var body: some View {
        NavigationStack {
            Group {
                if showingConsent {
                    consentView
                } else {
                    searchView
                }
            }
            .navigationTitle("OpenFoodFacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Consent gate (shown until the user proceeds once)

    private var consentView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "globe")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Search OpenFoodFacts?")
                .font(.title2).bold()

            Text("Searching sends what you type to OpenFoodFacts, an external food database, over the internet. Like any web request, it reaches their servers directly, and what they do with it is covered by their privacy policy. Budgie Diet never sees or keeps your searches, and this feature stays off unless you turn it on. You'll only be asked this the first time you choose to search with OpenFoodFacts.\n\nOpenFoodFacts' data was contributed by many different people around the world, and it may not be accurate, correct or up to date.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Link("OpenFoodFacts privacy policy",
                 destination: URL(string: "https://world.openfoodfacts.org/privacy")!)
                .font(.callout)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    settingsObj.offSearchConsented = true
                    showingConsent = false
                } label: {
                    Text("Search OpenFoodFacts").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button("Not now") { dismiss() }

                Button(role: .destructive) {
                    settingsObj.offSearchDisabled = true
                    dismiss()
                } label: {
                    Text("Disable this feature")
                }
            }
        }
        .padding()
    }

    private var searchView: some View {
        Group {
            if isSearching {
                ProgressView("Searching…")
            } else if let errorMessage {
                ContentUnavailableView("Couldn't search", systemImage: "wifi.slash",
                                       description: Text(errorMessage))
            } else if results.isEmpty {
                ContentUnavailableView.search(text: searchTerm)
            } else {
                List(results) { product in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                            if let brand = product.brand {
                                Text(brand).font(.caption).foregroundStyle(.secondary)
                            }
                            if let first = product.quantities.first {
                                Text(first.label).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let first = product.quantities.first {
                            Text("\(first.calories.formatted()) kcal").foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { importProduct(product) }
                }
            }
        }
        .searchable(text: $searchTerm, prompt: "Search OpenFoodFacts")
        .onSubmit(of: .search) { Task { await runSearch() } }
        .task { await runSearch() }   // initial search with the carried-over term
    }

    private func runSearch() async {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { results = []; return }
        isSearching = true
        errorMessage = nil
        do {
            results = try await OpenFoodFacts.search(term: term)
        } catch OpenFoodFacts.SearchError.rateLimited {
            errorMessage = "Too many searches just now — wait a moment and try again."
        } catch {
            print("OFF search error: \(error)")
            errorMessage = "Couldn't reach OpenFoodFacts. Check your connection and try again."
        }
        isSearching = false
    }

    private func importProduct(_ product: OFFProduct) {
        let food = product.toFoodItem()
        Task {
            let picked = await dataStore.foodItemActor.importOFF(food)   // reuses by barcode if already saved
            await MainActor.run {
                onImport(picked)            // → the add form in scaling mode
                dismiss()
            }
        }
    }
}
