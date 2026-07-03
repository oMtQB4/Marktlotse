//
//  VoiceMemoStore.swift
//  Marktlotse
//
//  Records and plays a short audio note attached to a barcode. Files are stored
//  in the app's Application Support directory, one file per barcode.
//
//  Recording runs through an AVAudioEngine with voice processing enabled, so the
//  system's acoustic echo canceller subtracts the device's own speaker output
//  (VoiceOver, playback, other apps) from the recorded mic signal. That keeps
//  VoiceOver — which a blind user needs while operating the app — out of the
//  memo. The app's *own* spoken announcements are additionally silenced for the
//  duration of the recording (see SpeechAnnouncer suppression below); the system
//  VoiceOver itself cannot be paused by an app, hence the echo cancellation.
//

import Foundation
import AVFoundation

@Observable
final class VoiceMemoStore: NSObject {

    static let maxDuration: TimeInterval = 30

    private(set) var isRecording = false
    private(set) var isPlaying = false
    private(set) var currentBarcode: String?

    private var engine: AVAudioEngine?
    private var recordingFile: AVAudioFile?
    private var maxDurationWorkItem: DispatchWorkItem?
    private var player: AVAudioPlayer?

    /// Used to mute the app's own spoken output while recording. Weak: AppServices
    /// owns the announcer; we only borrow it.
    private weak var speech: SpeechAnnouncer?

    private let fileManager = FileManager.default

    init(speech: SpeechAnnouncer? = nil) {
        self.speech = speech
        super.init()
    }

    private var directory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("voicememos", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func fileURL(for barcode: String) -> URL {
        let safe = barcode.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("\(safe).m4a")
    }

    func hasMemo(for barcode: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: barcode).path)
    }

    func deleteMemo(for barcode: String) {
        try? fileManager.removeItem(at: fileURL(for: barcode))
    }

    // MARK: - Recording

    func startRecording(for barcode: String) throws {
        stopPlaying()
        // Silence the app's own announcements; VoiceOver itself we can only keep
        // out of the recording via the echo canceller enabled below.
        speech?.beginRecordingSuppression()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                                options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        // Acoustic echo cancellation: the device's own output (VoiceOver, media)
        // is used as a reference signal and subtracted from the mic input.
        try input.setVoiceProcessingEnabled(true)

        // Read the tap format *after* enabling voice processing — it may change.
        let tapFormat = input.outputFormat(forBus: 0)

        let url = fileURL(for: barcode)
        try? fileManager.removeItem(at: url)

        let fileSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: tapFormat.sampleRate,
            AVNumberOfChannelsKey: Int(tapFormat.channelCount),
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let file = try AVAudioFile(forWriting: url, settings: fileSettings)

        input.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
            guard self?.recordingFile != nil else { return }
            try? file.write(from: buffer)
        }

        engine.prepare()
        try engine.start()

        self.engine = engine
        self.recordingFile = file
        isRecording = true
        currentBarcode = barcode

        // Enforce the maximum duration, mirroring AVAudioRecorder's forDuration:.
        let stopItem = DispatchWorkItem { [weak self] in self?.stopRecording() }
        maxDurationWorkItem = stopItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maxDuration, execute: stopItem)
    }

    func stopRecording() {
        guard isRecording else { return }
        maxDurationWorkItem?.cancel()
        maxDurationWorkItem = nil

        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        recordingFile = nil  // releasing the file flushes and closes it
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        speech?.endRecordingSuppression()
    }

    // MARK: - Playback

    func play(for barcode: String) throws {
        guard hasMemo(for: barcode) else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        player = try AVAudioPlayer(contentsOf: fileURL(for: barcode))
        player?.delegate = self
        player?.play()
        isPlaying = true
        currentBarcode = barcode
    }

    func stopPlaying() {
        player?.stop()
        player = nil
        isPlaying = false
    }
}

extension VoiceMemoStore: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
