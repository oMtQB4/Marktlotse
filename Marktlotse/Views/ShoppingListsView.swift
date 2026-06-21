//
//  ShoppingListsView.swift
//  Marktlotse
//
//  Overview of all shopping lists with create / delete support.
//

import SwiftUI
import SwiftData

struct ShoppingListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingList.createdAt, order: .reverse) private var lists: [ShoppingList]

    @State private var showNewList = false
    @State private var newListName = ""
    @State private var path: [ShoppingList] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if lists.isEmpty {
                    ContentUnavailableView {
                        Label("Keine Einkaufslisten", systemImage: "cart")
                    } description: {
                        Text("Erstelle eine Liste oder füge beim Scannen Produkte hinzu.")
                    } actions: {
                        Button("Liste erstellen") { showNewList = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(lists) { list in
                            NavigationLink(value: list) {
                                VStack(alignment: .leading) {
                                    Text(list.name).font(.headline)
                                    Text("\(list.openItemCount) von \(list.items.count) offen")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .onDelete(perform: deleteLists)
                    }
                }
            }
            .navigationTitle("Einkaufslisten")
            .navigationDestination(for: ShoppingList.self) { list in
                ShoppingListDetailView(list: list)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewList = true
                    } label: {
                        Label("Neue Liste", systemImage: "plus")
                    }
                }
            }
            .alert("Neue Einkaufsliste", isPresented: $showNewList) {
                TextField("Listenname", text: $newListName)
                Button("Erstellen") { createList() }
                Button("Abbrechen", role: .cancel) { newListName = "" }
            }
        }
        #if DEBUG
        .task(id: lists.map(\.id)) { openFirstListForScreenshotsIfNeeded() }
        #endif
    }

    #if DEBUG
    /// In screenshot mode, push straight into the first list to capture the
    /// detail view. Re-evaluated once the seeded lists arrive via @Query.
    private func openFirstListForScreenshotsIfNeeded() {
        guard ScreenshotSupport.isActive, ScreenshotSupport.openFirstList,
              path.isEmpty, let first = lists.first else { return }
        path = [first]
    }
    #endif

    private func createList() {
        let name = newListName.trimmingCharacters(in: .whitespaces)
        newListName = ""
        guard !name.isEmpty else { return }
        modelContext.insert(ShoppingList(name: name))
        try? modelContext.save()
    }

    private func deleteLists(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(lists[index])
        }
        try? modelContext.save()
    }
}
