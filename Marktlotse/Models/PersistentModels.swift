//
//  PersistentModels.swift
//  Marktlotse
//
//  SwiftData models for shopping lists, history and custom (own) article entries.
//

import Foundation
import SwiftData

/// A named shopping list that can hold several items.
@Model
final class ShoppingList {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ShoppingListItem.list)
    var items: [ShoppingListItem]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.items = []
    }

    /// Items sorted with unchecked first, then alphabetically.
    var sortedItems: [ShoppingListItem] {
        items.sorted { lhs, rhs in
            if lhs.isChecked != rhs.isChecked {
                return !lhs.isChecked && rhs.isChecked
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var openItemCount: Int {
        items.filter { !$0.isChecked }.count
    }
}

/// A single entry inside a `ShoppingList`.
@Model
final class ShoppingListItem {
    var id: UUID
    var title: String
    var barcode: String?
    var quantity: Int
    var isChecked: Bool
    var createdAt: Date
    var list: ShoppingList?

    init(title: String, barcode: String? = nil, quantity: Int = 1) {
        self.id = UUID()
        self.title = title
        self.barcode = barcode
        self.quantity = max(1, quantity)
        self.isChecked = false
        self.createdAt = Date()
    }
}

/// An item in the scan history.
@Model
final class HistoryEntry {
    var id: UUID
    var barcode: String
    var title: String
    var manufacturer: String?
    var scannedAt: Date

    init(barcode: String, title: String, manufacturer: String? = nil) {
        self.id = UUID()
        self.barcode = barcode
        self.title = title
        self.manufacturer = manufacturer
        self.scannedAt = Date()
    }
}

/// A user-defined ("own") article that overrides / supplements online lookups.
@Model
final class CustomArticle {
    @Attribute(.unique) var barcode: String
    var title: String
    var manufacturer: String?
    var memo: String?
    var updatedAt: Date

    init(barcode: String, title: String, manufacturer: String? = nil, memo: String? = nil) {
        self.barcode = barcode
        self.title = title
        self.manufacturer = manufacturer
        self.memo = memo
        self.updatedAt = Date()
    }
}
