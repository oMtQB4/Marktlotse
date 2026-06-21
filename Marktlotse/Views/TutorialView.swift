//
//  TutorialView.swift
//  Marktlotse
//
//  Accessible, text-first onboarding shown on first launch.
//

import SwiftUI

struct TutorialView: View {
    var onFinish: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let text: String
    }

    private let pages: [Page] = [
        Page(icon: "cart.fill",
             title: "Willkommen",
             text: "Marktlotse unterstützt dich beim selbstständigen Einkaufen. Wische nach rechts, um fortzufahren."),
        Page(icon: "barcode.viewfinder",
             title: "Scannen",
             text: "Halte den Barcode eines Produkts in den Kamerasucher. Das Produkt wird automatisch erkannt und vorgelesen."),
        Page(icon: "cart.badge.plus",
             title: "Einkaufslisten",
             text: "Lege Einkaufslisten an und hake Artikel beim Einkaufen ab."),
        Page(icon: "mic.circle.fill",
             title: "Sprachnotizen",
             text: "Nimm zu jedem Produkt eine eigene Sprachnotiz auf, zum Beispiel als persönliche Erinnerung."),
        Page(icon: "hand.tap.fill",
             title: "Bedienung mit VoiceOver",
             text: "Die App ist vollständig mit VoiceOver bedienbar. Ergebnisse können auch ohne VoiceOver vorgelesen werden.")
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 24) {
                        Image(systemName: item.icon)
                            .font(.system(size: 72))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(.largeTitle).bold()
                        Text(item.text)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .tag(index)
                    .accessibilityElement(children: .combine)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: advance) {
                Text(page == pages.count - 1 ? "Los geht's" : "Weiter")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()

            Button("Überspringen", action: onFinish)
                .padding(.bottom)
        }
    }

    private func advance() {
        if page == pages.count - 1 {
            onFinish()
        } else {
            withAnimation { page += 1 }
        }
    }
}
