//
//  ScanView.swift
//  Marktlotse
//
//  Camera scanning screen with manual entry fallback. Fully usable with
//  VoiceOver: results are announced and the detail screen receives focus.
//

import SwiftUI
import SwiftData
import AVFoundation

struct ScanView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var path: [Article] = []
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var isProcessing = false
    @State private var lastBarcode: String?
    @State private var lastScanTime = Date.distantPast
    @State private var showManualEntry = false
    @State private var manualBarcode = ""

    private var isScannerActive: Bool {
        path.isEmpty && !isProcessing && scenePhase == .active && !showManualEntry
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                cameraLayer
                overlay
            }
            .navigationTitle("Scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showManualEntry = true
                    } label: {
                        Label("Barcode eingeben", systemImage: "keyboard")
                    }
                    .accessibilityHint("Öffnet ein Feld zur manuellen Eingabe eines Barcodes")
                }
            }
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article)
            }
            .alert("Barcode eingeben", isPresented: $showManualEntry) {
                TextField("Barcode", text: $manualBarcode)
                    .keyboardType(.numberPad)
                Button("Suchen") { submitManualBarcode() }
                Button("Abbrechen", role: .cancel) { manualBarcode = "" }
            } message: {
                Text("Gib die Ziffern unter dem Barcode ein.")
            }
        }
    }

    // MARK: - Camera

    @ViewBuilder
    private var cameraLayer: some View {
        switch cameraStatus {
        case .authorized:
            CameraScannerView(onScan: handleScan, isActive: isScannerActive)
                .ignoresSafeArea(edges: .bottom)
                .accessibilityElement()
                .accessibilityLabel("Kamerasucher")
                .accessibilityHint("Richte die Kamera auf einen Barcode. Das Produkt wird automatisch erkannt.")
        case .notDetermined:
            permissionPrompt(message: "Für das Scannen wird Zugriff auf die Kamera benötigt.",
                             button: "Kamera erlauben") {
                AVCaptureDevice.requestAccess(for: .video) { _ in
                    DispatchQueue.main.async {
                        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    }
                }
            }
        default:
            permissionPrompt(message: "Der Kamerazugriff ist deaktiviert. Du kannst Barcodes manuell eingeben oder den Zugriff in den Einstellungen erlauben.",
                             button: "Einstellungen öffnen") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    @ViewBuilder
    private var overlay: some View {
        VStack {
            Spacer()
            if isProcessing {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Produkt wird gesucht …")
                        .font(.headline)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 32)
                .accessibilityElement(children: .combine)
            } else if cameraStatus == .authorized {
                Text("Barcode in den Sucher halten")
                    .font(.headline)
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 32)
                    .accessibilityHidden(true)
            }
        }
    }

    private func permissionPrompt(message: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .font(.body)
            Button(button, action: action)
                .buttonStyle(.borderedProminent)
            Button("Barcode manuell eingeben") { showManualEntry = true }
                .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Scan handling

    private func handleScan(_ barcode: String) {
        let now = Date()
        // Debounce duplicate reads of the same code within 2 seconds.
        if barcode == lastBarcode, now.timeIntervalSince(lastScanTime) < 2 { return }
        guard !isProcessing else { return }
        lastBarcode = barcode
        lastScanTime = now
        resolve(barcode)
    }

    private func submitManualBarcode() {
        let trimmed = manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines)
        manualBarcode = ""
        guard !trimmed.isEmpty else { return }
        resolve(trimmed)
    }

    private func resolve(_ barcode: String) {
        isProcessing = true
        if services.settings.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        Task { @MainActor in
            let repository = services.makeRepository(modelContext)
            let article = await repository.resolve(barcode: barcode)
            services.speech.announce(article.spokenSummary, speakAloud: services.settings.speakScanResults)
            isProcessing = false
            path.append(article)
        }
    }
}
