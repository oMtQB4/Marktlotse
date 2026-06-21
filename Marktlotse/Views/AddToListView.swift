//
//  AddToListView.swift
//  Marktlotse
//
//  Sheet to add a scanned article to an existing or new shopping list.
//

import SwiftUI
import SwiftData

struct AddToListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ShoppingList.createdAt, order: .reverse) private var lists: [ShoppingList]

    let article: Article

    @State private var quantity = 1
    @State private var newListName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Menge") {
                    Stepper(value: $quantity, in: 1...99) {
                        Text("\(quantity) Stück")
                    }
                    .accessibilityLabel("Menge")
                    .accessibilityValue("\(quantity) Stück")
                }

                Section("Vorhandene Liste") {
                    if lists.isEmpty {
                        Text("Noch keine Einkaufslisten vorhanden.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(lists) { list in
                            Button {
                                add(to: list)
                            } label: {
                                HStack {
                                    Text(list.name)
                                    Spacer()
                                    Text("\(list.openItemCount) offen")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityHint("Fügt \(article.displayTitle) zu \(list.name) hinzu")
                        }
                    }
                }

                Section("Neue Liste") {
                    TextField("Listenname", text: $newListName)
                    Button("Liste erstellen und hinzufügen") {
                        createListAndAdd()
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private func add(to list: ShoppingList) {
        let item = ShoppingListItem(title: article.displayTitle, barcode: article.barcode, quantity: quantity)
        item.list = list
        list.items.append(item)
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }

    private func createListAndAdd() {
        let name = newListName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let list = ShoppingList(name: name)
        modelContext.insert(list)
        add(to: list)
    }
}
