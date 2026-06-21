//
//  ScreenshotSupport.swift
//  Marktlotse
//
//  DEBUG-only helpers for generating App Store screenshots deterministically.
//  Activated with launch arguments, e.g.:
//    -ScreenshotMode 1 -ScreenshotTab 1 -ScreenshotOpenList 1 -hasSeenTutorial YES
//  None of this is compiled into release builds.
//

#if DEBUG
import Foundation
import SwiftData

enum ScreenshotSupport {

    /// True when the app was launched in screenshot mode.
    static var isActive: Bool {
        UserDefaults.standard.bool(forKey: "ScreenshotMode")
    }

    /// Initial tab to show (0 = Scannen, 1 = Einkaufslisten, 2 = Verlauf, 3 = Mehr).
    /// `integer(forKey:)` converts the string-valued launch argument to an Int.
    static var initialTab: Int {
        UserDefaults.standard.integer(forKey: "ScreenshotTab")
    }

    /// Whether to push straight into the first shopping list's detail view.
    static var openFirstList: Bool {
        UserDefaults.standard.bool(forKey: "ScreenshotOpenList")
    }

    /// Keeps the launch splash on screen (for capturing the splash itself).
    /// When false in screenshot mode, the splash is skipped so feature screens
    /// render immediately and can be captured without fighting launch timing.
    static var holdSplash: Bool {
        UserDefaults.standard.bool(forKey: "ScreenshotHoldSplash")
    }

    /// Replaces the store contents with a realistic demo data set. Idempotent
    /// across relaunches so every screenshot run starts from the same state.
    @MainActor
    static func seed(into context: ModelContext) {
        try? context.delete(model: ShoppingListItem.self)
        try? context.delete(model: ShoppingList.self)
        try? context.delete(model: HistoryEntry.self)

        // Inserted first so it sorts *below* the featured list (reverse by date).
        let drogerie = ShoppingList(name: "Drogerie")
        addItems(to: drogerie, in: context, [
            ("Zahnpasta", 2, false),
            ("Shampoo", 1, false),
            ("Taschentücher", 3, true)
        ])

        // Featured list — shown in the list-detail screenshot. Mixed quantities
        // and check states to highlight the per-item quantity display.
        let wocheneinkauf = ShoppingList(name: "Wocheneinkauf")
        addItems(to: wocheneinkauf, in: context, [
            ("Vollkornbrot", 1, false),
            ("Milch", 2, false),
            ("Äpfel", 6, false),
            ("Joghurt", 4, false),
            ("Eier", 1, true),
            ("Kaffeebohnen", 1, true)
        ])

        // Scan history.
        let now = Date()
        let history: [(String, String, String?)] = [
            ("5411188119098", "Bio Hafermilch", "Alpro"),
            ("4011800013004", "Vollkorn Toast", "Harry"),
            ("8710912345678", "Gouda jung", "Frico"),
            ("8001120000123", "Tomatenmark", "Mutti"),
            ("4001234567890", "Mineralwasser Naturell", "Gerolsteiner")
        ]
        for (offset, entry) in history.enumerated() {
            let item = HistoryEntry(barcode: entry.0, title: entry.1, manufacturer: entry.2)
            item.scannedAt = Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now
            context.insert(item)
        }

        try? context.save()
    }

    @MainActor
    private static func addItems(to list: ShoppingList,
                                 in context: ModelContext,
                                 _ items: [(String, Int, Bool)]) {
        context.insert(list)
        for (title, quantity, checked) in items {
            let item = ShoppingListItem(title: title, quantity: quantity)
            item.isChecked = checked
            item.list = list
            list.items.append(item)
            context.insert(item)
        }
    }
}
#endif
