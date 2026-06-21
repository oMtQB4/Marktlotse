//
//  ArticleDetailView.swift
//  Marktlotse
//
//  Shows a resolved product, lets the user record a voice memo, add the item
//  to a shopping list, and create / edit a custom entry.
//

import SwiftUI
import SwiftData

struct ArticleDetailView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext

    let article: Article

    @State private var showAddToList = false
    @State private var showCustomEditor = false
    @State private var hasVoiceMemo = false

    private var voiceStore: VoiceMemoStore { services.voiceMemoStore }

    /// Recording/playing state derived from the shared store, scoped to this article.
    private var isRecording: Bool {
        voiceStore.isRecording && voiceStore.currentBarcode == article.barcode
    }
    private var isPlaying: Bool {
        voiceStore.isPlaying && voiceStore.currentBarcode == article.barcode
    }

    var body: some View {
        List {
            productSection
            ratingSection
            nutritionSection
            ingredientsSection
            allergensSection
            labelsSection
            voiceMemoSection
            actionSection
        }
        .navigationTitle(article.isResolved ? "Produkt" : "Kein Treffer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { hasVoiceMemo = voiceStore.hasMemo(for: article.barcode) }
        .onDisappear {
            voiceStore.stopPlaying()
            if isRecording { voiceStore.stopRecording() }
        }
        .onChange(of: isRecording) { _, recording in
            if !recording { hasVoiceMemo = voiceStore.hasMemo(for: article.barcode) }
        }
        .sheet(isPresented: $showAddToList) {
            AddToListView(article: article)
        }
        .sheet(isPresented: $showCustomEditor) {
            CustomEntryEditorView(barcode: article.barcode, prefill: article)
        }
    }

    // MARK: - Sections

    private var productSection: some View {
        Section {
            if article.isResolved {
                LabeledContent("Produkt", value: article.displayTitle)
                if let manufacturer = article.manufacturer, !manufacturer.isEmpty {
                    LabeledContent("Hersteller", value: manufacturer)
                }
                if let detail = article.detailName, !detail.isEmpty, detail != article.title {
                    LabeledContent("Bezeichnung", value: detail)
                }
                if let quantity = article.quantity, !quantity.isEmpty {
                    LabeledContent("Menge", value: quantity)
                }
                if let serving = article.servingSize, !serving.isEmpty {
                    LabeledContent("Portionsgröße", value: serving)
                }
                if let desc = article.descriptionText, !desc.isEmpty {
                    LabeledContent("Beschreibung", value: desc)
                }
                if let category = article.category, !category.isEmpty {
                    LabeledContent("Kategorie", value: category)
                }
            } else {
                Text("Zu diesem Barcode wurde kein Produkt gefunden. Du kannst einen eigenen Eintrag anlegen oder eine Sprachnotiz aufnehmen.")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Barcode", value: article.barcode)
                .accessibilityValue(article.spokenBarcode)
        } header: {
            Text(sourceLabel)
        }
    }

    private var sourceLabel: String {
        switch article.source {
        case .openGTIN: return "OpenGTINDB"
        case .openFoodFacts: return "Open Food Facts"
        case .customEntry: return "Eigener Eintrag"
        case .voiceMemoOnly: return "Nur Sprachnotiz"
        case .unknown: return "Unbekannt"
        }
    }

    @ViewBuilder
    private var ratingSection: some View {
        if article.nutriScore != nil || article.novaGroup != nil {
            Section("Bewertung") {
                if let grade = article.nutriScore {
                    LabeledContent("Nutri-Score", value: grade.uppercased())
                        .accessibilityLabel("Nutri-Score")
                        .accessibilityValue("Klasse \(grade.uppercased())")
                }
                if let nova = article.novaGroup {
                    LabeledContent("Verarbeitungsgrad (NOVA)", value: "\(nova) von 4")
                        .accessibilityLabel("Verarbeitungsgrad nach NOVA")
                        .accessibilityValue("Gruppe \(nova) von 4, \(novaDescription(nova))")
                    Text(novaDescription(nova))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var nutritionSection: some View {
        if let n = article.nutrition {
            Section("Nährwerte (pro \(n.basis))") {
                nutritionRow("Energie", n.energyKcal, unit: "kcal")
                nutritionRow("Fett", n.fat, unit: "g")
                nutritionRow("davon gesättigte Fettsäuren", n.saturatedFat, unit: "g")
                nutritionRow("Kohlenhydrate", n.carbohydrates, unit: "g")
                nutritionRow("davon Zucker", n.sugars, unit: "g")
                nutritionRow("Ballaststoffe", n.fiber, unit: "g")
                nutritionRow("Eiweiß", n.proteins, unit: "g")
                nutritionRow("Salz", n.salt, unit: "g")
            }
        }
    }

    @ViewBuilder
    private func nutritionRow(_ label: String, _ value: Double?, unit: String) -> some View {
        if let value {
            LabeledContent(label, value: formatNutrient(value, unit: unit))
        }
    }

    @ViewBuilder
    private var ingredientsSection: some View {
        if let ingredients = article.ingredients, !ingredients.isEmpty {
            Section("Zutaten") {
                Text(ingredients)
            }
        }
    }

    @ViewBuilder
    private var allergensSection: some View {
        if let allergens = article.allergens, !allergens.isEmpty {
            Section("Allergene") {
                Text(allergens.joined(separator: ", "))
            }
        }
    }

    @ViewBuilder
    private var labelsSection: some View {
        if let labels = article.labels, !labels.isEmpty {
            Section("Kennzeichnungen") {
                Text(labels.joined(separator: ", "))
            }
        }
    }

    private func novaDescription(_ group: Int) -> String {
        switch group {
        case 1: return "Unverarbeitet oder gering verarbeitet"
        case 2: return "Verarbeitete Küchenzutaten"
        case 3: return "Verarbeitete Lebensmittel"
        case 4: return "Hochverarbeitete Lebensmittel"
        default: return "Unbekannt"
        }
    }

    private func formatNutrient(_ value: Double, unit: String) -> String {
        let number: String
        if unit == "kcal" {
            number = String(format: "%.0f", value)
        } else {
            number = String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
        }
        return "\(number) \(unit)"
    }

    private var voiceMemoSection: some View {
        Section("Sprachnotiz") {
            Button {
                toggleRecording()
            } label: {
                Label(isRecording ? "Aufnahme beenden" : (hasVoiceMemo ? "Neu aufnehmen" : "Aufnehmen"),
                      systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill")
            }
            .accessibilityHint(isRecording ? "Beendet die laufende Aufnahme" : "Nimmt eine Sprachnotiz von bis zu 30 Sekunden auf")

            if hasVoiceMemo {
                Button {
                    togglePlay()
                } label: {
                    Label(isPlaying ? "Wiedergabe stoppen" : "Abspielen",
                          systemImage: isPlaying ? "stop.circle" : "play.circle")
                }
                Button(role: .destructive) {
                    voiceStore.deleteMemo(for: article.barcode)
                    hasVoiceMemo = false
                } label: {
                    Label("Sprachnotiz löschen", systemImage: "trash")
                }
            }
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                showAddToList = true
            } label: {
                Label("Zur Einkaufsliste hinzufügen", systemImage: "cart.badge.plus")
            }
            Button {
                showCustomEditor = true
            } label: {
                Label(services.makeRepository(modelContext).customArticle(for: article.barcode) != nil
                      ? "Eigenen Eintrag bearbeiten" : "Eigenen Eintrag anlegen",
                      systemImage: "square.and.pencil")
            }
        }
    }

    // MARK: - Voice memo control

    private func toggleRecording() {
        if isRecording {
            voiceStore.stopRecording()
            hasVoiceMemo = voiceStore.hasMemo(for: article.barcode)
        } else {
            voiceStore.stopPlaying()
            try? voiceStore.startRecording(for: article.barcode)
        }
    }

    private func togglePlay() {
        if isPlaying {
            voiceStore.stopPlaying()
        } else {
            try? voiceStore.play(for: article.barcode)
        }
    }
}
