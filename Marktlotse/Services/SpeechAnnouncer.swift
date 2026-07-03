//
//  SpeechAnnouncer.swift
//  Marktlotse
//
//  Announces scan results. When VoiceOver is active it posts an accessibility
//  announcement; otherwise it can speak the result aloud (useful for blind
//  users who navigate by touch without VoiceOver running).
//

import Foundation
import UIKit
import AVFoundation

final class SpeechAnnouncer {

    private let synthesizer = AVSpeechSynthesizer()

    /// While true, no announcement or speech is emitted. Set during voice-memo
    /// recording so the app's own output doesn't bleed into the memo. Note: this
    /// only silences *our* output — the system VoiceOver cannot be paused by an
    /// app and is instead kept out of the recording by echo cancellation.
    private var isRecordingSuppressed = false

    /// Silence all output and stop any in-progress utterance for a recording.
    func beginRecordingSuppression() {
        isRecordingSuppressed = true
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Resume normal output after a recording ends.
    func endRecordingSuppression() {
        isRecordingSuppressed = false
    }

    /// Announce a message. `force` speaks aloud even if VoiceOver is off.
    func announce(_ message: String, speakAloud: Bool) {
        guard !isRecordingSuppressed else { return }
        if UIAccessibility.isVoiceOverRunning {
            // Let VoiceOver read it; avoids double speech.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        } else if speakAloud {
            speak(message)
        }
    }

    func speak(_ message: String) {
        configureSessionForPlayback()
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func configureSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }
}
