//
//  RootView.swift
//  Marktlotse
//
//  Root container: shows the onboarding tutorial on first launch, otherwise
//  the main tab interface.
//

import SwiftUI

struct RootView: View {
    @Environment(AppServices.self) private var services
    @State private var showTutorial = false
    @State private var showSplash: Bool = {
        #if DEBUG
        if ScreenshotSupport.isActive { return ScreenshotSupport.holdSplash }
        #endif
        return true
    }()

    var body: some View {
        MainTabView()
            .fullScreenCover(isPresented: $showTutorial) {
                TutorialView {
                    services.settings.hasSeenTutorial = true
                    showTutorial = false
                }
            }
            .overlay {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                #if DEBUG
                // In screenshot mode the splash is either held for its own shot
                // or skipped entirely; never auto-dismiss or show the tutorial.
                if ScreenshotSupport.isActive { return }
                #endif
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeInOut(duration: 0.45)) {
                    showSplash = false
                }
                // Present the onboarding tutorial only once the splash is gone,
                // so it never covers the startup screen on first launch.
                if !services.settings.hasSeenTutorial {
                    showTutorial = true
                }
            }
    }
}

struct MainTabView: View {
    @State private var selection: Int = {
        #if DEBUG
        return ScreenshotSupport.isActive ? ScreenshotSupport.initialTab : 0
        #else
        return 0
        #endif
    }()

    var body: some View {
        TabView(selection: $selection) {
            ScanView()
                .tag(0)
                .tabItem {
                    Label("Scannen", systemImage: "barcode.viewfinder")
                }

            ShoppingListsView()
                .tag(1)
                .tabItem {
                    Label("Einkaufslisten", systemImage: "cart")
                }

            HistoryView()
                .tag(2)
                .tabItem {
                    Label("Verlauf", systemImage: "clock")
                }

            MoreView()
                .tag(3)
                .tabItem {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
        }
    }
}
