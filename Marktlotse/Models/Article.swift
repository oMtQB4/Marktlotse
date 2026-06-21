//
//  Article.swift
//  Marktlotse
//
//  Value type representing a resolved product. This is the result of a barcode
//  lookup and is not persisted directly (history / custom entries are).
//

import Foundation

/// Where the article information originated from.
enum ArticleSource: String, Codable {
    case openGTIN
    case openFoodFacts
    case customEntry
    case voiceMemoOnly
    case unknown
}

/// Nutrition values, typically per 100 g / 100 ml.
struct NutritionFacts: Hashable {
    var basis: String          // e.g. "100 g" or "100 ml"
    var energyKcal: Double?
    var fat: Double?
    var saturatedFat: Double?
    var carbohydrates: Double?
    var sugars: Double?
    var fiber: Double?
    var proteins: Double?
    var salt: Double?

    var hasAnyValue: Bool {
        [energyKcal, fat, saturatedFat, carbohydrates, sugars, fiber, proteins, salt]
            .contains { $0 != nil }
    }
}

/// A resolved (or unresolved) product.
struct Article: Identifiable, Hashable {
    var id: String { barcode }

    let barcode: String
    var title: String?
    var manufacturer: String?
    var detailName: String?
    var descriptionText: String?
    var category: String?
    var source: ArticleSource

    // Extended product details (currently provided by Open Food Facts).
    var quantity: String? = nil
    var servingSize: String? = nil
    var ingredients: String? = nil
    var allergens: [String]? = nil
    var labels: [String]? = nil
    var nutriScore: String? = nil      // "a" ... "e"
    var novaGroup: Int? = nil          // 1 ... 4
    var nutrition: NutritionFacts? = nil

    /// Whether any meaningful product information was found.
    var isResolved: Bool {
        switch source {
        case .openGTIN, .openFoodFacts, .customEntry:
            return !(title?.isEmpty ?? true)
        case .voiceMemoOnly, .unknown:
            return false
        }
    }

    /// A display title that always returns something readable.
    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return barcode
    }

    /// A short spoken summary suitable for a VoiceOver announcement.
    var spokenSummary: String {
        var parts: [String] = []
        if isResolved {
            parts.append(displayTitle)
            if let manufacturer, !manufacturer.isEmpty {
                parts.append("von \(manufacturer)")
            }
        } else {
            parts.append("Kein Produkt gefunden")
            parts.append("Barcode \(spokenBarcode)")
        }
        return parts.joined(separator: ", ")
    }

    /// Barcode read out digit by digit for clarity.
    var spokenBarcode: String {
        barcode.map { String($0) }.joined(separator: " ")
    }

    static func unresolved(barcode: String, hasVoiceMemo: Bool) -> Article {
        Article(
            barcode: barcode,
            title: nil,
            manufacturer: nil,
            detailName: nil,
            descriptionText: nil,
            category: nil,
            source: hasVoiceMemo ? .voiceMemoOnly : .unknown
        )
    }
}
