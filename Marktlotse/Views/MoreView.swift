//
//  MoreView.swift
//  Marktlotse
//
//  Settings, tutorial access and app information.
//

import SwiftUI

struct MoreView: View {
    @Environment(AppServices.self) private var services
    @State private var showTutorial = false

    var body: some View {
        @Bindable var settings = services.settings
        NavigationStack {
            Form {
                Section("Vorlesen") {
                    Toggle("Ergebnisse vorlesen", isOn: $settings.speakScanResults)
                        .accessibilityHint("Liest das gefundene Produkt laut vor, auch wenn VoiceOver aus ist.")
                    Toggle("Haptisches Feedback", isOn: $settings.hapticsEnabled)
                }

                Section {
                    Picker("Kameralicht", selection: $settings.torchMode) {
                        ForEach(TorchMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .accessibilityHint("Legt fest, wann das Kameralicht beim Scannen leuchtet.")
                } header: {
                    Text("Kameralicht")
                } footer: {
                    Text("Automatisch: leuchtet bei Dunkelheit. Letzter Status: merkt sich die letzte Wahl und sagt sie beim Öffnen an. Immer an / Immer aus: fest eingestellt.")
                }

                Section {
                    Button("Einführung erneut ansehen") { showTutorial = true }
                }

                Section {
                    NavigationLink("Über die App") { AboutView() }
                    NavigationLink("Nutzungsbedingungen") { TermsOfUseView() }
                    Link(destination: LegalDocuments.privacyPolicyURL) {
                        HStack {
                            Text("Datenschutz")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint("Öffnet die Datenschutzerklärung im Browser.")
                    NavigationLink("Lizenzen / Open Source") { LicensesView() }
                }

                Section("Quellcode") {
                    Link(destination: URL(string: "https://github.com/oMtQB4/Marktlotse")!) {
                        Label("Projekt auf GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Text("Der Quellcode wird mit dem ersten Release öffentlich verfügbar gemacht.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Mehr")
            .fullScreenCover(isPresented: $showTutorial) {
                TutorialView { showTutorial = false }
            }
        }
    }
}

struct AboutView: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return v
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                    Text("Marktlotse")
                        .font(.title2).bold()
                    Text("Version \(version)")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .accessibilityElement(children: .combine)
            }
            Section {
                Text("Diese App unterstützt blinde und sehbehinderte Menschen beim selbstständigen Einkaufen. Sie erkennt Produkt-Barcodes mit der Kamera und liest die Produktinformationen vor.")
            }
        }
        .navigationTitle("Über die App")
        .navigationBarTitleDisplayMode(.inline)
    }
}
