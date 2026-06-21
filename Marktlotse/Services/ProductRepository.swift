//
//  ProductRepository.swift
//  Marktlotse
//
//  Orchestrates a barcode lookup across the available sources:
//  1. User-defined custom entries (offline, highest priority)
//  2. Online product database (OpenGTINDB)
//  3. Fallback: voice-memo-only / unknown
//  Successful resolutions are added to the scan history.
//

import Foundation
import SwiftData

@MainActor
final class ProductRepository {

    private let lookupService: ProductLookupService
    private let voiceMemoStore: VoiceMemoStore
    private let modelContext: ModelContext

    init(lookupService: ProductLookupService,
         voiceMemoStore: VoiceMemoStore,
         modelContext: ModelContext) {
        self.lookupService = lookupService
        self.voiceMemoStore = voiceMemoStore
        self.modelContext = modelContext
    }

    /// Resolve an article for a barcode, recording it in history when meaningful.
    func resolve(barcode: String) async -> Article {
        let hasMemo = voiceMemoStore.hasMemo(for: barcode)

        // 1. Custom (own) entry.
        if let custom = customArticle(for: barcode) {
            let article = Article(
                barcode: barcode,
                title: custom.title,
                manufacturer: custom.manufacturer,
                detailName: nil,
                descriptionText: custom.memo,
                category: nil,
                source: .customEntry
            )
            record(article)
            return article
        }

        // 2. Online lookup.
        do {
            let article = try await lookupService.lookup(barcode: barcode)
            record(article)
            return article
        } catch {
            // 3. Fallback.
            return Article.unresolved(barcode: barcode, hasVoiceMemo: hasMemo)
        }
    }

    // MARK: - Custom entries

    func customArticle(for barcode: String) -> CustomArticle? {
        let descriptor = FetchDescriptor<CustomArticle>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func saveCustomArticle(barcode: String, title: String, manufacturer: String?, memo: String?) {
        if let existing = customArticle(for: barcode) {
            existing.title = title
            existing.manufacturer = manufacturer
            existing.memo = memo
            existing.updatedAt = Date()
        } else {
            let entry = CustomArticle(barcode: barcode, title: title, manufacturer: manufacturer, memo: memo)
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }

    func deleteCustomArticle(for barcode: String) {
        if let existing = customArticle(for: barcode) {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    // MARK: - History

    private func record(_ article: Article) {
        guard article.isResolved else { return }
        let entry = HistoryEntry(
            barcode: article.barcode,
            title: article.displayTitle,
            manufacturer: article.manufacturer
        )
        modelContext.insert(entry)
        trimHistory()
        try? modelContext.save()
    }

    private func trimHistory(limit: Int = 100) {
        var descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        guard let entries = try? modelContext.fetch(descriptor), entries.count > limit else { return }
        for entry in entries[limit...] {
            modelContext.delete(entry)
        }
    }
}
