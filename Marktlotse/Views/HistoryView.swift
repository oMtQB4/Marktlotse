//
//  HistoryView.swift
//  Marktlotse
//
//  Shows previously scanned articles.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HistoryEntry.scannedAt, order: .reverse) private var entries: [HistoryEntry]

    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView("Kein Verlauf",
                                           systemImage: "clock",
                                           description: Text("Gescannte Produkte erscheinen hier."))
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink(value: entry) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title).font(.headline)
                                    if let manufacturer = entry.manufacturer, !manufacturer.isEmpty {
                                        Text(manufacturer).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Text(entry.scannedAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Verlauf")
            .navigationDestination(for: HistoryEntry.self) { entry in
                ArticleDetailView(article: Article(
                    barcode: entry.barcode,
                    title: entry.title,
                    manufacturer: entry.manufacturer,
                    detailName: nil,
                    descriptionText: nil,
                    category: nil,
                    source: .openGTIN
                ))
            }
            .toolbar {
                if !entries.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Verlauf löschen", systemImage: "trash")
                        }
                        .accessibilityHint("Entfernt alle Produkte aus dem Verlauf")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
            .confirmationDialog("Verlauf löschen?",
                                isPresented: $showClearConfirmation,
                                titleVisibility: .visible) {
                Button("Verlauf löschen", role: .destructive) { clearAll() }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Alle gescannten Produkte werden aus dem Verlauf entfernt.")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
        try? modelContext.save()
    }

    private func clearAll() {
        try? modelContext.delete(model: HistoryEntry.self)
        try? modelContext.save()
    }
}
