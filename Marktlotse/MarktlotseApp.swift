//
//  MarktlotseApp.swift
//  Marktlotse
//
//  App entry point. Sets up SwiftData and the shared service container.
//

import SwiftUI
import SwiftData

@main
struct MarktlotseApp: App {

    @State private var services = AppServices()

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            ShoppingList.self,
            ShoppingListItem.self,
            HistoryEntry.self,
            CustomArticle.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Konnte den Datenspeicher nicht erstellen: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .tint(.accentColor)
                .task {
                    #if DEBUG
                    if ScreenshotSupport.isActive {
                        ScreenshotSupport.seed(into: modelContainer.mainContext)
                    }
                    #endif
                }
        }
        .modelContainer(modelContainer)
    }
}
