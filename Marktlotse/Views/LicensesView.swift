//
//  LicensesView.swift
//  Marktlotse
//
//  Open-source license overview for all bundled third-party components.
//

import SwiftUI

/// A single third-party component and its license.
struct LicenseComponent: Identifiable {
    let id = UUID()
    let name: String
    let copyright: String
    let licenseName: String
    let licenseText: String
    let url: URL?
}

struct LicensesView: View {
    var body: some View {
        List {
            Section {
                Text("Marktlotse nutzt die folgenden Open-Source-Komponenten. Die jeweiligen Lizenztexte sind unten vollständig wiedergegeben.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Softwarebibliotheken") {
                ForEach(LicenseCatalog.libraries) { component in
                    NavigationLink {
                        LicenseDetailView(component: component)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(component.name)
                            Text(component.licenseName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Section("Datenquellen") {
                Text("Produktinformationen von Open Food Facts.")
                Link("openfoodfacts.org", destination: URL(string: "https://world.openfoodfacts.org")!)
                Text("Daten von Open Food Facts stehen unter der Open Database License (ODbL) 1.0.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Link("ODbL 1.0", destination: URL(string: "https://opendatacommons.org/licenses/odbl/1-0/")!)
            }

            Section("Hinweis zu Google ML Kit") {
                Text("Die Barcode-Erkennung verwendet Google ML Kit. Die Nutzung unterliegt zusätzlich zu den genannten Open-Source-Lizenzen den ML-Kit-Nutzungsbedingungen von Google.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Link("ML Kit Terms", destination: URL(string: "https://developers.google.com/ml-kit/terms")!)
            }
        }
        .navigationTitle("Lizenzen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LicenseDetailView: View {
    let component: LicenseComponent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(component.copyright)
                    .font(.subheadline)
                Text(component.licenseName)
                    .font(.subheadline).bold()
                if let url = component.url {
                    Link(url.absoluteString, destination: url)
                        .font(.footnote)
                }
                Divider()
                Text(component.licenseText)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(component.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Static catalog of bundled third-party components (via CocoaPods).
enum LicenseCatalog {
    static let libraries: [LicenseComponent] = [
        LicenseComponent(
            name: "Google ML Kit (Barcode Scanning)",
            copyright: "Copyright Google LLC",
            licenseName: "Apache License 2.0",
            licenseText: LicenseTexts.apache2,
            url: URL(string: "https://developers.google.com/ml-kit")
        ),
        LicenseComponent(
            name: "MLKitBarcodeScanning, MLKitVision, MLKitCommon, MLImage",
            copyright: "Copyright Google LLC",
            licenseName: "Apache License 2.0",
            licenseText: LicenseTexts.apache2,
            url: URL(string: "https://developers.google.com/ml-kit")
        ),
        LicenseComponent(
            name: "GoogleDataTransport",
            copyright: "Copyright Google LLC",
            licenseName: "Apache License 2.0",
            licenseText: LicenseTexts.apache2,
            url: URL(string: "https://github.com/google/GoogleDataTransport")
        ),
        LicenseComponent(
            name: "GoogleToolboxForMac",
            copyright: "Copyright Google Inc.",
            licenseName: "Apache License 2.0",
            licenseText: LicenseTexts.apache2,
            url: URL(string: "https://github.com/google/google-toolbox-for-mac")
        ),
        LicenseComponent(
            name: "GoogleUtilities",
            copyright: "Copyright Google LLC",
            licenseName: "Apache License 2.0",
            licenseText: LicenseTexts.apache2,
            url: URL(string: "https://github.com/google/GoogleUtilities")
        ),
        LicenseComponent(
            name: "GTMSessionFetcher",
            copyright: "Copyright Google Inc.",
            licenseName: "Apache License 2.0",
            licenseText: LicenseTexts.apache2,
            url: URL(string: "https://github.com/google/gtm-session-fetcher")
        ),
        LicenseComponent(
            name: "Google Promises (PromisesObjC)",
            copyright: "Copyright Google Inc.",
            licenseName: "Apache License 2.0",
            licenseText: LicenseTexts.apache2,
            url: URL(string: "https://github.com/google/promises")
        ),
        LicenseComponent(
            name: "nanopb",
            copyright: "Copyright (c) 2011 Petteri Aimonen",
            licenseName: "zlib License",
            licenseText: LicenseTexts.zlib,
            url: URL(string: "https://github.com/nanopb/nanopb")
        ),
    ]
}
