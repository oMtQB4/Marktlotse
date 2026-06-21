//
//  PrivacyPolicyView.swift
//  Marktlotse
//
//  Datenschutzerklärung. Reflects the app's actual data handling: everything is
//  stored locally; the only third-party transmission is the scanned barcode sent
//  to Open Food Facts for product lookups. No own servers, no tracking.
//

import SwiftUI

struct PrivacyPolicyView: View {

    // TODO: Vor Veröffentlichung mit den echten Angaben des Verantwortlichen füllen.
    private let controllerName = "Dr. Jan Roters"
    private let controllerAddress = ""
    private let controllerEmail = "apps.roters+ml@gmail.com"

    var body: some View {
        List {
            Section {
                Text("Marktlotse hilft beim selbstständigen Einkaufen. Die App ist auf Datensparsamkeit ausgelegt: Wir betreiben keine eigenen Server und übertragen keine Daten an uns. Persönliche Inhalte bleiben auf Ihrem Gerät.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Verantwortlich") {
                Text("Verantwortlich im Sinne der Datenschutz-Grundverordnung (DSGVO):")
                Text("\(controllerName)\n\(controllerAddress)\nE-Mail: \(controllerEmail)")
                    .accessibilityElement(children: .combine)
            }

            Section("Daten auf Ihrem Gerät") {
                Text("Folgende Inhalte werden ausschließlich lokal auf Ihrem Gerät gespeichert und nicht übertragen:")
                bullet("Einkaufslisten und deren Artikel")
                bullet("der Scan-Verlauf")
                bullet("selbst angelegte Artikeleinträge")
                bullet("Sprachnotizen zu Produkten")
                bullet("App-Einstellungen")
                Text("Diese Daten verlassen Ihr Gerät nicht. Sie können sie jederzeit in der App oder durch Deinstallation der App löschen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Kamera und Mikrofon") {
                Text("Kamera: Wird zum Scannen von Barcodes benötigt. Die Barcode-Erkennung läuft vollständig auf dem Gerät (Google ML Kit). Es werden keine Bilder gespeichert oder übertragen.")
                Text("Mikrofon: Wird ausschließlich für selbst aufgenommene Sprachnotizen verwendet. Die Aufnahmen bleiben lokal auf dem Gerät.")
                Text("Sie können diese Berechtigungen jederzeit in den Einstellungen Ihres Geräts widerrufen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Produktsuche über Open Food Facts") {
                Text("Zum Abrufen von Produktinformationen wird der gescannte oder manuell eingegebene Barcode über eine verschlüsselte Verbindung (HTTPS) an den externen Dienst Open Food Facts (world.openfoodfacts.org) gesendet. Dies ist die einzige Datenübermittlung an Dritte.")
                Text("Dabei werden übertragen: der Produkt-Barcode (EAN/GTIN), eine Programmkennung (User-Agent Marktlotse) sowie technisch notwendige Verbindungsdaten wie Ihre IP-Adresse, die der Server zur Beantwortung der Anfrage benötigt.")
                Text("Es werden keine Namen, Benutzerkonten, Geräte-Kennungen oder Standortdaten übermittelt.")
                Text("Beim Start der App wird die Verbindung zu Open Food Facts bereits vorbereitet, um spätere Suchen zu beschleunigen. Dabei wird noch kein Barcode übertragen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Open Food Facts ist ein gemeinnütziges, offenes Projekt. Für die dortige Verarbeitung gelten die Datenschutzbestimmungen von Open Food Facts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Link("openfoodfacts.org", destination: URL(string: "https://world.openfoodfacts.org")!)
            }

            Section("Kein Tracking, keine Werbung, kein Konto") {
                Text("Wir betreiben keine eigenen Server und speichern keine Ihrer Daten bei uns. Es findet keine Analyse oder Nachverfolgung Ihres Verhaltens statt, es wird keine Werbung angezeigt, und es ist kein Benutzerkonto erforderlich. Außer der oben beschriebenen Produktsuche bei Open Food Facts werden keine Daten an Dritte weitergegeben.")
            }

            Section("Ihre Rechte") {
                Text("Da persönliche Inhalte nur lokal gespeichert werden, haben Sie die volle Kontrolle darüber. Nach der DSGVO haben Sie das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung sowie Datenübertragbarkeit.")
                Text("Sie können Verlauf, Listen, eigene Einträge und Sprachnotizen jederzeit in der App entfernen. Durch Deinstallation der App werden alle lokal gespeicherten Daten gelöscht.")
            }

            Section("Rechtsgrundlage") {
                Text("Die Verarbeitung bei der Produktsuche erfolgt auf Ihre Veranlassung zur Bereitstellung der von Ihnen angeforderten Funktion (Art. 6 Abs. 1 lit. b und f DSGVO).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Stand und Änderungen") {
                Text("Diese Datenschutzerklärung kann angepasst werden, wenn sich die App ändert. Es gilt die jeweils in der App angezeigte Fassung.")
                Text("Stand: Juni 2026")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Datenschutz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").accessibilityHidden(true)
            Text(text)
        }
    }
}
