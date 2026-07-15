//
//  ConsentView.swift
//  Marktlotse
//
//  Zustimmungsdialog beim ersten Start. Der Nutzer durchläuft drei Schritte und
//  stimmt jedem einzeln zu:
//    1. Datenschutzerklärung
//    2. Nutzungsbedingungen
//    3. Hinweis zur Eigenverantwortung (keine Gewähr für Produktinformationen)
//  Text-first und vollständig mit VoiceOver bedienbar; die vollständigen
//  Dokumente sind über Verweise erreichbar.
//

import SwiftUI

/// Shared references to the app's legal documents. The privacy policy is hosted
/// online so it is maintained in a single place (the website), avoiding a second
/// copy inside the app. The terms of use are shown locally (see `TermsOfUseView`).
enum LegalDocuments {
    static let privacyPolicyURL = URL(string: "https://apps-roters.de/marktlotse/datenschutz.html")!
}

struct ConsentView: View {
    /// Called once the user has accepted all three steps.
    var onAccept: () -> Void

    /// The steps of the consent flow, accepted one after another.
    private enum Step: Int, CaseIterable {
        case privacy
        case terms
        case responsibility
    }

    @State private var step: Step = .privacy

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    switch step {
                    case .privacy: privacyStep
                    case .terms: termsStep
                    case .responsibility: responsibilityStep
                    }
                }

                footer
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            // Announce each step change so VoiceOver users notice the new content.
            .id(step)
        }
    }

    // MARK: - Steps

    private var privacyStep: some View {
        stepContainer(
            icon: "hand.raised.fill",
            title: "Datenschutzerklärung",
            message: "Willkommen bei Marktlotse. Bitte lesen Sie zuerst die Datenschutzerklärung. Um fortzufahren, müssen Sie ihr zustimmen."
        ) {
            Link(destination: LegalDocuments.privacyPolicyURL) {
                documentRow(title: "Datenschutzerklärung lesen", icon: "hand.raised", isExternal: true)
            }
        }
    }

    private var termsStep: some View {
        stepContainer(
            icon: "doc.text.fill",
            title: "Nutzungsbedingungen",
            message: "Bitte lesen Sie nun die Nutzungsbedingungen. Um fortzufahren, müssen Sie auch diesen zustimmen."
        ) {
            NavigationLink {
                TermsOfUseView()
            } label: {
                documentRow(title: "Nutzungsbedingungen lesen", icon: "doc.text", isExternal: false)
            }
        }
    }

    private var responsibilityStep: some View {
        stepContainer(
            icon: "exclamationmark.triangle.fill",
            title: "Wichtiger Hinweis",
            message: "Bitte bestätigen Sie zum Schluss, dass Sie den folgenden Hinweis verstanden haben."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Die angezeigten Produktinformationen stammen aus offenen Fremddatenbanken und können unvollständig, veraltet oder falsch sein. Der Autor der App übernimmt keine Verantwortung für falsche Angaben.")
                Text("Verlassen Sie sich nicht allein auf die App. Gehen Sie sorgsam mit den Ergebnissen um und fragen Sie im Zweifel eine sehende Person, um ein gescanntes Produkt zu überprüfen – besonders bei Allergien, Unverträglichkeiten oder Medikamenten.")
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Chrome

    private var footer: some View {
        VStack(spacing: 12) {
            Text(footerCaption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: advance) {
                Text(primaryButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.bar)
    }

    private var footerCaption: String {
        switch step {
        case .privacy:
            return "Mit „Zustimmen“ akzeptieren Sie die Datenschutzerklärung."
        case .terms:
            return "Mit „Zustimmen“ akzeptieren Sie die Nutzungsbedingungen."
        case .responsibility:
            return "Schritt 3 von 3."
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .privacy, .terms: return "Zustimmen und weiter"
        case .responsibility: return "Verstanden und fortfahren"
        }
    }

    private func advance() {
        switch step {
        case .privacy:
            withAnimation { step = .terms }
        case .terms:
            withAnimation { step = .responsibility }
        case .responsibility:
            onAccept()
        }
    }

    // MARK: - Building blocks

    private func stepContainer<Content: View>(
        icon: String,
        title: String,
        message: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(title)
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)

            Text(message)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            content()
                .padding(.top, 8)
        }
        .padding()
    }

    private func documentRow(title: String, icon: String, isExternal: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .accessibilityHint(isExternal ? "Öffnet den vollständigen Text im Browser." : "Öffnet den vollständigen Text.")
    }
}
