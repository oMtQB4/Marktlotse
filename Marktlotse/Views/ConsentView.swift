//
//  ConsentView.swift
//  Marktlotse
//
//  Zustimmungsdialog beim ersten Start: Der Nutzer muss die Nutzungsbedingungen
//  und die Datenschutzerklärung annehmen, bevor die App verwendet werden kann.
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
    /// Called when the user accepts the terms of use and privacy policy.
    var onAccept: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)

                        Text("Willkommen bei Marktlotse")
                            .font(.largeTitle).bold()
                            .multilineTextAlignment(.center)

                        Text("Bevor es losgeht, lesen Sie bitte die Nutzungsbedingungen und die Datenschutzerklärung. Um die App zu verwenden, müssen Sie beiden zustimmen.")
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 12) {
                            NavigationLink {
                                TermsOfUseView()
                            } label: {
                                documentRow(title: "Nutzungsbedingungen", icon: "doc.text", isExternal: false)
                            }

                            Link(destination: LegalDocuments.privacyPolicyURL) {
                                documentRow(title: "Datenschutzerklärung", icon: "hand.raised", isExternal: true)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }

                VStack(spacing: 12) {
                    Text("Mit „Zustimmen und fortfahren“ akzeptieren Sie die Nutzungsbedingungen und die Datenschutzerklärung.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: onAccept) {
                        Text("Zustimmen und fortfahren")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
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
