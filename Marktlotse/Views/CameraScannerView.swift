//
//  CameraScannerView.swift
//  Marktlotse
//
//  Camera barcode scanner using Google ML Kit, wrapped for SwiftUI.
//

import SwiftUI
import AVFoundation
import MLKitBarcodeScanning
import MLKitVision

/// SwiftUI wrapper around the camera capture controller.
struct CameraScannerView: UIViewControllerRepresentable {

    /// Called with a recognised barcode (deduplicated by the parent view).
    var onScan: (String) -> Void
    /// Whether the scanner is actively running.
    var isActive: Bool

    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let controller = CameraScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ controller: CameraScannerViewController, context: Context) {
        controller.onScan = onScan
        if isActive {
            controller.startScanning()
        } else {
            controller.stopScanning()
        }
    }
}

/// UIKit controller managing the AVCaptureSession and preview layer.
final class CameraScannerViewController: UIViewController, BarcodeScannerSource {

    let kind: ScannerKind = .camera
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoQueue = DispatchQueue(label: "de.apps-roters.video")
    private let sessionQueue = DispatchQueue(label: "de.apps-roters.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false

    /// Google ML Kit barcode scanner configured for the common retail formats.
    private lazy var barcodeScanner: BarcodeScanner = {
        let options = BarcodeScannerOptions(formats: [
            .EAN8, .EAN13, .UPCA, .UPCE, .code128, .code39, .code93, .ITF, .qrCode, .PDF417
        ])
        return BarcodeScanner.barcodeScanner(options: options)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSessionIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.sessionQueue.async {
                self.setupSession()
            }
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        // 720p keeps per-frame ML Kit processing fast; combined with near-range
        // autofocus this reads small barcodes reliably without 1080p overhead.
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        configureFocus(for: device)

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            return
        }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        session.addOutput(videoOutput)

        session.commitConfiguration()
        isConfigured = true

        DispatchQueue.main.async {
            let preview = AVCaptureVideoPreviewLayer(session: self.session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = self.view.bounds
            self.view.layer.insertSublayer(preview, at: 0)
            self.previewLayer = preview
            self.startScanning()
        }
    }

    /// Configures the camera to keep close-up barcodes sharp: continuous
    /// autofocus restricted to the near range, focused on the centre of the frame.
    private func configureFocus(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            // Snappier refocus on a static barcode than the smoothed video ramp.
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = false
            }
        } catch {
            // Focus tuning is best-effort; scanning still works with defaults.
        }
    }

    func start() { startScanning() }
    func stop() { stopScanning() }

    func startScanning() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopScanning() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
}

extension CameraScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Process synchronously on the video queue. Frames that arrive while a
        // scan is in flight are dropped by `alwaysDiscardsLateVideoFrames`, which
        // throttles us without a main-thread round-trip — much faster than the
        // async `process(completion:)` path whose callback hops to the main thread.
        let image = VisionImage(buffer: sampleBuffer)
        image.orientation = imageOrientation()

        guard let barcodes = try? barcodeScanner.results(in: image),
              let value = barcodes.first(where: { ($0.rawValue?.isEmpty == false) })?.rawValue
        else { return }

        DispatchQueue.main.async { self.onScan?(value) }
    }

    /// Maps the (portrait-locked) back camera feed to the correct image orientation.
    private func imageOrientation() -> UIImage.Orientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right
        }
    }
}
