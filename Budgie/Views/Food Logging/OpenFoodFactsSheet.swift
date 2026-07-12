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

            Text("Searching sends what you type to OpenFoodFacts, an external food database, over the internet. Like any web request, it reaches their servers directly, and what they do with it is covered by their privacy policy. Budgie Diet never sees or keeps your searches, and this stays off unless you turn it on.")
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

    // MARK: - Search (placeholder — network + results land in step 2)

    private var searchView: some View {
        ContentUnavailableView(
            "Search coming soon",
            systemImage: "magnifyingglass",
            description: Text("Searching “\(searchTerm)” on OpenFoodFacts isn't wired up yet.")
        )
        .searchable(text: $searchTerm, prompt: "Search OpenFoodFacts")
    }
}
