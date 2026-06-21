//
//  VoiceMemoStore.swift
//  Marktlotse
//
//  Records and plays a short audio note attached to a barcode. Files are stored
//  in the app's Application Support directory, one file per barcode.
//

import Foundation
import AVFoundation

@Observable
final class VoiceMemoStore: NSObject {

    static let maxDuration: TimeInterval = 30

    private(set) var isRecording = false
    private(set) var isPlaying = false
    private(set) var currentBarcode: String?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

    private let fileManager = FileManager.default

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
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let url = fileURL(for: barcode)
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = self
        recorder?.record(forDuration: Self.maxDuration)
        isRecording = true
        currentBarcode = barcode
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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

extension VoiceMemoStore: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
