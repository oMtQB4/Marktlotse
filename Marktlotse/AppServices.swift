//
//  AppServices.swift
//  Marktlotse
//
//  Central, lightweight dependency container shared through the SwiftUI
//  environment.
//

import Foundation
import SwiftData

@Observable
final class AppServices {

    let settings: AppSettings
    let voiceMemoStore: VoiceMemoStore
    let speech: SpeechAnnouncer
    let lookupService: ProductLookupService

    init() {
        let settings = AppSettings()
        self.settings = settings
        let speech = SpeechAnnouncer()
        self.speech = speech
        // The memo store silences the announcer while recording so the app's own
        // spoken output doesn't bleed into the recording.
        self.voiceMemoStore = VoiceMemoStore(speech: speech)
        // The Open Facts family is the active product source: food first (richest
        // data — nutrition, ingredients, allergens), then the sibling databases
        // that fill the non-food gaps (general products, drugstore/cosmetics, pet
        // food). All are key-free and queried in order; the first match wins.
        // OpenGTINDB is currently disabled; to re-enable it, add it to the array:
        //   let openGTIN = OpenGTINService(queryIDProvider: { settings.openGTINQueryID })
        self.lookupService = CompositeProductLookupService(services: [
            OpenFactsService.foodFacts(),
            OpenFactsService.productsFacts(),
            OpenFactsService.beautyFacts(),
            OpenFactsService.petFoodFacts()
        ])

        // Open the connection to the product API at launch so the first scan
        // isn't delayed by DNS/TLS setup. Silent, best-effort, no UI.
        self.lookupService.warmUp()
    }

    @MainActor
    func makeRepository(_ context: ModelContext) -> ProductRepository {
        ProductRepository(
            lookupService: lookupService,
            voiceMemoStore: voiceMemoStore,
            modelContext: context
        )
    }
}
