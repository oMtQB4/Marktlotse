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
    private var captureDevice: AVCaptureDevice?

    // Multi-frame confirmation: a value must be read this many times in a row
    // before it is accepted, which rejects transient misreads from blurry frames.
    // (Accessed only on `videoQueue`.)
    private var pendingCode: String?
    private var pendingCount = 0
    private let requiredConsecutiveReads = 3
    /// Formats that carry a check digit we can verify to reject misreads early.
    private let checksummedFormats: BarcodeFormat = [.EAN13, .EAN8, .UPCA]

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
        captureDevice = device
        configureFocus(for: device)
        NotificationCenter.default.addObserver(
            self, selector: #selector(subjectAreaDidChange),
            name: .AVCaptureDeviceSubjectAreaDidChange, object: device)

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

            // Tap-to-focus as a manual fallback if autofocus can't lock on.
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleFocusTap(_:)))
            self.view.addGestureRecognizer(tap)

            self.startScanning()
        }
    }

    /// Configures the camera so close-up barcodes stay sharp: continuous
    /// autofocus on the centre of the frame, plus a zoom factor that compensates
    /// for the lens' minimum focus distance.
    private func configureFocus(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            // Re-run autofocus whenever the scene changes (e.g. a barcode is
            // brought into view), so focus doesn't stay stuck on the background.
            device.isSubjectAreaChangeMonitoringEnabled = true

            applyMinimumFocusZoom(to: device)
        } catch {
            // Focus tuning is best-effort; scanning still works with defaults.
        }
    }

    /// Many iPhones (especially Pro models) have a minimum focus distance of
    /// 12–20 cm, so a small barcode held close is physically out of focus range
    /// and never decodes. Zoom in just enough that a small code fills the frame
    /// from a distance the lens *can* focus on. (Apple's recommended approach,
    /// see the `AVCaptureDevice.minimumFocusDistance` documentation.)
    private func applyMinimumFocusZoom(to device: AVCaptureDevice) {
        let minFocusDistance = Float(device.minimumFocusDistance)  // mm, or -1 if unknown
        guard minFocusDistance > 0 else { return }

        let fieldOfView = device.activeFormat.videoFieldOfView      // horizontal degrees
        let minimumCodeSizeMM: Float = 15        // support codes down to ~15 mm wide
        let previewFill: Float = 0.25            // such a code should fill ~25% of the width

        let halfAngle = (fieldOfView / 2) * .pi / 180
        guard halfAngle > 0 else { return }
        let framedCodeSize = minimumCodeSizeMM / previewFill
        let focusableDistance = framedCodeSize / tan(halfAngle)     // mm

        guard focusableDistance < minFocusDistance else { return }
        let zoom = CGFloat(minFocusDistance / focusableDistance)
        device.videoZoomFactor = min(zoom, device.activeFormat.videoMaxZoomFactor)
    }

    /// Re-trigger continuous autofocus on the centre when the scene changes.
    @objc private func subjectAreaDidChange(_ notification: Notification) {
        sessionQueue.async {
            guard let device = self.captureDevice else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            } catch { }
        }
    }

    /// Focus on the tapped point (manual fallback).
    @objc private func handleFocusTap(_ gesture: UITapGestureRecognizer) {
        guard let previewLayer, let device = captureDevice else { return }
        let layerPoint = gesture.location(in: view)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                }
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            } catch { }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() { startScanning() }
    func stop() { stopScanning() }

    func startScanning() {
        videoQueue.async {
            self.pendingCode = nil
            self.pendingCount = 0
        }
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
              let barcode = barcodes.first(where: { ($0.rawValue?.isEmpty == false) }),
              let value = barcode.rawValue
        else { return }

        // Reject EAN/UPC reads whose check digit doesn't add up — these are
        // almost always misreads from a blurry frame.
        if checksummedFormats.contains(barcode.format), !Barcode.hasValidCheckDigit(value) {
            return
        }

        // Require the same value on several consecutive frames before accepting.
        // Blurry frames decode varying (wrong) values, so they never reach the
        // threshold; only a stable, sharp read does.
        if value == pendingCode {
            pendingCount += 1
        } else {
            pendingCode = value
            pendingCount = 1
        }
        guard pendingCount >= requiredConsecutiveReads else { return }
        pendingCount = 0

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
