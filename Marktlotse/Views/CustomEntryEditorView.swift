//
//  CustomEntryEditorView.swift
//  Marktlotse
//
//  Create or edit a user-defined ("own") article for a barcode.
//

import SwiftUI
import SwiftData

struct CustomEntryEditorView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let barcode: String
    let prefill: Article?

    @State private var title = ""
    @State private var manufacturer = ""
    @State private var memo = ""
    @State private var loaded = false
    @State private var existed = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Produkt") {
                    TextField("Titel", text: $title)
                    TextField("Hersteller", text: $manufacturer)
                }
                Section("Notiz") {
                    TextField("Notiz", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    LabeledContent("Barcode", value: barcode)
                        .accessibilityValue(barcode.map { String($0) }.joined(separator: " "))
                }
                if existed {
                    Section {
                        Button(role: .destructive) {
                            services.makeRepository(modelContext).deleteCustomArticle(for: barcode)
                            dismiss()
                        } label: {
                            Text("Eigenen Eintrag löschen")
                        }
                    }
                }
            }
            .navigationTitle("Eigener Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let existing = services.makeRepository(modelContext).customArticle(for: barcode) {
            title = existing.title
            manufacturer = existing.manufacturer ?? ""
            memo = existing.memo ?? ""
            existed = true
        } else if let prefill, prefill.isResolved {
            title = prefill.title ?? ""
            manufacturer = prefill.manufacturer ?? ""
            memo = prefill.descriptionText ?? ""
        }
    }

    private func save() {
        services.makeRepository(modelContext).saveCustomArticle(
            barcode: barcode,
            title: title.trimmingCharacters(in: .whitespaces),
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            memo: memo.isEmpty ? nil : memo
        )
        dismiss()
    }
}
