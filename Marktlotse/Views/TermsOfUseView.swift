//
//  TermsOfUseView.swift
//  Marktlotse
//
//  Nutzungsbedingungen. Bewusst knapp und verständlich gehalten. Wichtig für
//  eine Einkaufshilfe: Produktdaten stammen aus offenen Fremdquellen und können
//  falsch oder unvollständig sein – die App ersetzt keine eigene Prüfung,
//  besonders bei Allergien und Unverträglichkeiten.
//

import SwiftUI

struct TermsOfUseView: View {

    var body: some View {
        List {
            Section {
                Text("Diese Nutzungsbedingungen regeln die Verwendung der App Marktlotse. Mit der Nutzung der App erklären Sie sich mit diesen Bedingungen einverstanden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Zweck der App") {
                Text("Marktlotse unterstützt blinde und sehbehinderte Menschen beim selbstständigen Einkaufen. Die App erkennt Produkt-Barcodes mit der Kamera und liest Produktinformationen vor. Sie ist eine Hilfe und ersetzt weder eine ärztliche Beratung noch die eigenverantwortliche Prüfung von Produkten.")
            }

            Section("Produktinformationen ohne Gewähr") {
                Text("Die angezeigten Produktinformationen stammen aus offenen Fremddatenbanken wie Open Food Facts sowie aus selbst angelegten Einträgen. Diese Daten werden von Dritten gepflegt und können unvollständig, veraltet oder falsch sein.")
                Text("Verlassen Sie sich bei wichtigen Entscheidungen – insbesondere bei Allergien, Unverträglichkeiten, Medikamenten oder Ernährungsvorgaben – nicht allein auf die App. Prüfen Sie im Zweifel die Angaben auf der Produktverpackung oder holen Sie sich Unterstützung.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Verantwortungsvolle Nutzung") {
                Text("Nutzen Sie die App nicht in Situationen, in denen Ihre Aufmerksamkeit an anderer Stelle erforderlich ist, etwa im Straßenverkehr. Verwenden Sie die App nur im Rahmen der geltenden Gesetze.")
            }

            Section("Verfügbarkeit") {
                Text("Für die Produktsuche wird eine Internetverbindung benötigt. Auf dessen Verfügbarkeit und auf die Verfügbarkeit der abzurufenden Internetservices haben wir keinen Einfluss. Es besteht kein Anspruch auf eine ununterbrochene Verfügbarkeit der App oder einzelner Funktionen.")
            }

            Section("Haftung") {
                Text("Die App wird mit größtmöglicher Sorgfalt bereitgestellt, jedoch ohne Gewähr für die Richtigkeit, Vollständigkeit und Aktualität der angezeigten Informationen.")
                Text("Für Schäden, die aus der Nutzung oder Nichtverfügbarkeit der App entstehen, wird nur bei Vorsatz oder grober Fahrlässigkeit gehaftet. Die Haftung nach zwingenden gesetzlichen Vorschriften, etwa bei Verletzung von Leben, Körper oder Gesundheit, bleibt unberührt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Datenschutz") {
                Text("Wie mit Ihren Daten umgegangen wird, ist in der Datenschutzerklärung beschrieben. Sie finden diese jederzeit im Bereich „Mehr“.")
            }

            Section("Änderungen") {
                Text("Diese Nutzungsbedingungen können angepasst werden, wenn sich die App ändert. Es gilt die jeweils in der App angezeigte Fassung.")
                Text("Stand: Juli 2026")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Nutzungsbedingungen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
