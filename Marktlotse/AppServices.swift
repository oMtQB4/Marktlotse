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
        self.voiceMemoStore = VoiceMemoStore()
        self.speech = SpeechAnnouncer()
        // Open Food Facts is the active product source (rich food data incl.
        // nutrition, ingredients, allergens). OpenGTINDB is currently disabled;
        // to re-enable it, add it to the services array below:
        //   let openGTIN = OpenGTINService(queryIDProvider: { settings.openGTINQueryID })
        let openFoodFacts = OpenFoodFactsService()
        self.lookupService = CompositeProductLookupService(services: [openFoodFacts])
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
