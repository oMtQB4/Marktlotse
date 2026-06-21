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

    /// Announce a message. `force` speaks aloud even if VoiceOver is off.
    func announce(_ message: String, speakAloud: Bool) {
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
