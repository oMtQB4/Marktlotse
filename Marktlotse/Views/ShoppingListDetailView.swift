//
//  ShoppingListDetailView.swift
//  Marktlotse
//
//  Items of a single shopping list: check off, change quantity, add, delete.
//

import SwiftUI
import SwiftData

struct ShoppingListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var list: ShoppingList

    @State private var showAddItem = false
    @State private var newItemTitle = ""

    var body: some View {
        List {
            if list.items.isEmpty {
                Text("Diese Liste ist leer.")
                    .foregroundStyle(.secondary)
            }
            ForEach(list.sortedItems) { item in
                itemRow(item)
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddItem = true
                } label: {
                    Label("Artikel hinzufügen", systemImage: "plus")
                }
            }
        }
        .alert("Artikel hinzufügen", isPresented: $showAddItem) {
            TextField("Artikelname", text: $newItemTitle)
            Button("Hinzufügen") { addItem() }
            Button("Abbrechen", role: .cancel) { newItemTitle = "" }
        }
    }

    private func itemRow(_ item: ShoppingListItem) -> some View {
        HStack {
            Button {
                item.isChecked.toggle()
                try? modelContext.save()
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? Color.accentColor : Color.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isChecked ? "Erledigt" : "Offen")
            .accessibilityHint("Doppeltippen, um den Status zu ändern")

            VStack(alignment: .leading) {
                Text(item.title)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
            }
            Spacer()
            Text("\(item.quantity)×")
                .monospacedDigit()
                .font(.body.weight(.medium))
                .foregroundStyle(item.isChecked ? .secondary : .primary)
                .frame(minWidth: 36, alignment: .trailing)
                .accessibilityHidden(true)
            Stepper(value: Binding(
                get: { item.quantity },
                set: { item.quantity = max(1, $0); try? modelContext.save() }
            ), in: 1...99) {
                Text("\(item.quantity)×")
                    .monospacedDigit()
            }
            .labelsHidden()
            .accessibilityLabel("Menge für \(item.title)")
            .accessibilityValue("\(item.quantity)")
        }
        .accessibilityElement(children: .contain)
    }

    private func addItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespaces)
        newItemTitle = ""
        guard !title.isEmpty else { return }
        let item = ShoppingListItem(title: title)
        item.list = list
        list.items.append(item)
        modelContext.insert(item)
        try? modelContext.save()
    }

    private func deleteItems(at offsets: IndexSet) {
        let sorted = list.sortedItems
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        try? modelContext.save()
    }
}
