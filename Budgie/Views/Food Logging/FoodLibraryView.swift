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

struct FoodLibraryView: View {
    @EnvironmentObject var todayLump: TodayLump
    @State private var foodToLog: FoodItem?
    @State private var foodToEdit: FoodItem?
    @State private var foods: [FoodItem] = []
    @State private var searchText: String = ""
    @State private var showArchived: Bool = false
    @State private var showingNewFood: Bool = false
    @State private var reloadToken = UUID()

    private struct QueryKey: Equatable {
        var term: String
        var archived: Bool
        var reload: UUID
    }
    private var queryKey: QueryKey {
        QueryKey(term: searchText, archived: showArchived, reload: reloadToken)
    }

    var body: some View {
        List {
            if foods.isEmpty {
                Text(searchText.isEmpty ? "You haven't saved any foods yet." : "No foods match your search.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(foods) { food in
                    foodRow(food)
                        .contentShape(Rectangle())
                        .onTapGesture { foodToLog = food }
                        .swipeActions(edge: .leading) {            // swipe right → edit
                            Button {
                                foodToEdit = food
                            } label: { Label("Edit", systemImage: "pencil") }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {           // swipe left → archive
                            Button {
                                Task { await setArchived(food, archived: !food.archived) }
                            } label: {
                                Label(food.archived ? "Unarchive" : "Archive",
                                      systemImage: food.archived ? "tray.and.arrow.up" : "archivebox")
                            }
                            .tint(.orange)
                        }
                }
            }
        }
        .navigationTitle("Your foods")
        .searchable(text: $searchText, prompt: "Search foods")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New food", systemImage: "plus") { showingNewFood = true }
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Toggle("Show archived", isOn: $showArchived)
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task(id: queryKey) {
            if searchText.isEmpty {
                foods = await dataStore.foodItemActor.fetchAll(includeArchived: showArchived)
            } else {
                foods = await dataStore.foodItemActor.search(term: searchText, includeArchived: showArchived)
            }
        }
        .sheet(isPresented: $showingNewFood) {
            NavigationStack { FoodEditorView(isModal: true) }
                .onDisappear { reloadToken = UUID() }
        }
        
        .sheet(item: $foodToLog) { food in
            NavigationStack {
                AddCalsSheet(selectedDate: Date(), preselectedFood: food.asPicked)
                    .environmentObject(todayLump)
            }
            .onDisappear { reloadToken = UUID() }
        }
        .sheet(item: $foodToEdit) { food in
            NavigationStack {
                FoodEditorView(existing: food, isModal: true)
            }
            .onDisappear { reloadToken = UUID() }
        }
    }

    @ViewBuilder
    private func foodRow(_ food: FoodItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let m = food.manufacturer, !m.isEmpty {
                Text(m).font(.caption).foregroundStyle(.secondary)
            }
            Text(food.name)
            if let first = food.quantities.first {
                Text("\(first.calories.formatted()) kcal per \(first.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if food.archived {
                Text("Archived").font(.caption2).italic().foregroundStyle(.secondary)
            }
        }
    }

    private func setArchived(_ food: FoodItem, archived: Bool) async {
        await dataStore.foodItemActor.setArchived(id: food.id, archived: archived)
        reloadToken = UUID()
    }
}

#Preview {
    NavigationStack {
        FoodLibraryView()
    }
    .environmentObject(TodayLump())
}
