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
    /// How the torch should behave while scanning.
    var torchMode: TorchMode
    /// Remembered LED state for `.remember` mode.
    var torchWasOn: Bool
    /// Reports the physical LED state to the UI (button icon).
    var onTorchChange: (Bool) -> Void
    /// Reports a user-initiated LED change so it can be persisted.
    var onUserToggle: (Bool) -> Void
    /// Hands the controller back to the parent so it can trigger a manual toggle.
    var onController: (CameraScannerViewController) -> Void

    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let controller = CameraScannerViewController()
        controller.onScan = onScan
        controller.onTorchChange = onTorchChange
        controller.onUserToggle = onUserToggle
        onController(controller)
        return controller
    }

    func updateUIViewController(_ controller: CameraScannerViewController, context: Context) {
        controller.onScan = onScan
        controller.onTorchChange = onTorchChange
        controller.onUserToggle = onUserToggle
        controller.torchWasOn = torchWasOn
        controller.torchMode = torchMode
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

    // MARK: Torch state
    /// Selected torch behaviour; applying it re-evaluates the LED. (main thread)
    var torchMode: TorchMode = .alwaysOff {
        didSet {
            guard torchMode != oldValue else { return }
            sessionQueue.async { self.applyTorchMode() }
        }
    }
    /// Remembered LED state for `.remember` mode (fed from settings). (main thread)
    var torchWasOn = false
    /// Notifies the UI whenever the physical LED state changes (button icon).
    var onTorchChange: ((Bool) -> Void)?
    /// Notifies the UI when the *user* toggled the LED (so it can be persisted).
    var onUserToggle: ((Bool) -> Void)?
    /// Current physical LED state. (sessionQueue)
    private var torchOn = false
    /// True once the user manually overrode the automatic mode this session.
    private var autoOverridden = false
    /// Throttles automatic on/off decisions. (videoQueue)
    private var lastAutoSwitch = Date.distantPast

    // Multi-frame confirmation: a value must be read this many times in a row
    // before it is accepted, which rejects transient misreads from blurry frames.
    // (Accessed only on `videoQueue`.)
    private var pendingCode: String?
    private var pendingCount = 0
    // All active formats carry a check digit (verified below), so two stable
    // reads are enough to reject blurry-frame misreads while staying responsive.
    private let requiredConsecutiveReads = 2
    /// Formats that carry a check digit we can verify to reject misreads early.
    private let checksummedFormats: BarcodeFormat = [.EAN13, .EAN8]

    /// Google ML Kit barcode scanner. Restricted to EAN-8 and EAN-13 — the only
    /// formats this app needs (the European retail barcodes on groceries). The
    /// fewer formats ML Kit considers, the less work it does per frame, so
    /// detection is as fast as possible; re-add formats here if a need comes up.
    private lazy var barcodeScanner: BarcodeScanner = {
        let options = BarcodeScannerOptions(formats: [.EAN8, .EAN13])
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

        guard let device = preferredCaptureDevice(),
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
        applyTorchMode()

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

    /// Picks the back lens that focuses best on close barcodes. The ultra-wide
    /// lens focuses from ~2 cm to infinity, so it stays sharp across the whole
    /// 10–20 cm range (and beyond) where the main wide lens on recent models
    /// can't focus closer than ~20 cm — but only if that ultra-wide lens can
    /// autofocus (on some non-Pro phones it's fixed focus). Otherwise the plain
    /// autofocusing wide lens is the safer choice.
    private func preferredCaptureDevice() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera],
            mediaType: .video, position: .back)
        if let ultraWide = discovery.devices.first(where: { $0.deviceType == .builtInUltraWideCamera }),
           ultraWide.isFocusModeSupported(.continuousAutoFocus) {
            return ultraWide
        }
        if let wide = discovery.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            return wide
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// Configures the camera for codes held ~10–20 cm away.
    private func configureFocus(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.deviceType == .builtInUltraWideCamera {
                // Crop the very wide (~0.5x) field of view back to roughly the
                // normal "1x" framing, while keeping the lens' close-focus range.
                device.videoZoomFactor = min(2.0, device.activeFormat.videoMaxZoomFactor)
            } else {
                // Wide lens: keep 1x and bias autofocus to the near range so it
                // locks on close barcodes instead of hunting out to infinity.
                device.videoZoomFactor = 1.0
                if device.isAutoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .near
                }
            }

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            // Re-run autofocus whenever the scene changes (e.g. a barcode is
            // brought into view), so focus doesn't stay stuck on the background.
            device.isSubjectAreaChangeMonitoringEnabled = true
        } catch {
            // Focus tuning is best-effort; scanning still works with defaults.
        }
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

    /// User tapped the torch button: flip the LED and, in automatic mode, stop
    /// the brightness logic from overriding that choice for the rest of the
    /// session. Reports the new state so the UI can persist it (`.remember` mode).
    func toggleTorch() {
        sessionQueue.async {
            self.autoOverridden = true
            let newState = !self.torchOn
            self.setTorch(newState)
            DispatchQueue.main.async { self.onUserToggle?(newState) }
        }
    }

    /// Applies the current `torchMode` to the LED. (Call on sessionQueue.)
    private func applyTorchMode() {
        autoOverridden = false
        switch torchMode {
        case .alwaysOn: setTorch(true)
        case .alwaysOff: setTorch(false)
        case .remember: setTorch(torchWasOn)
        case .auto: break   // decided from frame brightness in captureOutput
        }
    }

    /// Drives the LED to `on`, using a gentler level for automatic activation.
    /// Notifies the UI only on an actual change. (Call on sessionQueue.)
    private func setTorch(_ on: Bool) {
        guard let device = captureDevice, device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if on {
                // Automatic mode uses a softer level (not full glare); a manual /
                // always-on choice gets full brightness.
                let level: Float = (torchMode == .auto && !autoOverridden) ? 0.6 : 1.0
                try? device.setTorchModeOn(level: min(level, AVCaptureDevice.maxAvailableTorchLevel))
            } else {
                device.torchMode = .off
            }
        } catch { return }

        guard torchOn != on else { return }
        torchOn = on
        DispatchQueue.main.async { self.onTorchChange?(on) }
    }

    /// In automatic mode, switch the LED on when the scene is dark and off when
    /// it's clearly bright. Throttled and hysteretic to avoid flicker (the LED
    /// itself raises the reading, so the off-threshold is higher). (videoQueue)
    private func evaluateAutoTorch(_ sampleBuffer: CMSampleBuffer) {
        guard torchMode == .auto, !autoOverridden else { return }
        let now = Date()
        guard now.timeIntervalSince(lastAutoSwitch) > 1.0 else { return }
        guard let brightness = Self.exifBrightness(sampleBuffer) else { return }

        let shouldBeOn = torchOn ? (brightness < 3.0) : (brightness < 0.5)
        guard shouldBeOn != torchOn else { return }
        lastAutoSwitch = now
        sessionQueue.async { self.setTorch(shouldBeOn) }
    }

    /// Reads the EXIF brightness (APEX) value the camera attaches to each frame.
    /// Higher is brighter; bright daylight is ~7+, a dim room near 0, dark below.
    private static func exifBrightness(_ sampleBuffer: CMSampleBuffer) -> Double? {
        guard let attachments = CMCopyDictionaryOfAttachments(
                allocator: kCFAllocatorDefault, target: sampleBuffer,
                attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [String: Any],
              let exif = attachments[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let brightness = exif[kCGImagePropertyExifBrightnessValue as String] as? Double
        else { return nil }
        return brightness
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
            // Restore the configured torch behaviour each time scanning resumes.
            self.applyTorchMode()
        }
    }

    func stopScanning() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            // The session stop turns the LED off; reflect that in the UI without
            // touching the remembered state.
            if self.torchOn {
                self.torchOn = false
                DispatchQueue.main.async { self.onTorchChange?(false) }
            }
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
        evaluateAutoTorch(sampleBuffer)

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
