//
//  AppSettings.swift
//  Marktlotse
//
//  Small observable wrapper around UserDefaults for app preferences.
//

import Foundation
import SwiftUI

/// How the camera torch (LED) behaves while scanning.
enum TorchMode: String, CaseIterable, Identifiable {
    /// Switch the LED on automatically when the scene is too dark.
    case auto
    /// Restore whatever state the user last chose, announced on start.
    case remember
    /// LED always on while scanning.
    case alwaysOn
    /// LED always off (manual toggle still works for the session).
    case alwaysOff

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Automatisch bei Dunkelheit"
        case .remember: return "Letzter Status"
        case .alwaysOn: return "Immer an"
        case .alwaysOff: return "Immer aus"
        }
    }
}

@Observable
final class AppSettings {

    /// Default community query id for OpenGTINDB. Users may register their own
    /// at https://opengtindb.org and enter it in the settings.
    static let defaultOpenGTINQueryID = "400000000"

    private let defaults: UserDefaults

    private enum Keys {
        static let queryID = "openGTINQueryID"
        static let speakResults = "speakScanResults"
        static let hapticsEnabled = "hapticsEnabled"
        static let hasSeenTutorial = "hasSeenTutorial"
        static let hasAcceptedLegalTerms = "hasAcceptedLegalTerms"
        static let torchMode = "torchMode"
        static let torchWasOn = "torchWasOn"
    }

    /// How the camera torch behaves while scanning. Defaults to automatic, which
    /// suits users who can't judge the ambient light themselves. Stored (not a
    /// computed UserDefaults wrapper) so `@Observable` tracks it and the settings
    /// Picker updates instead of snapping back.
    var torchMode: TorchMode {
        didSet { defaults.set(torchMode.rawValue, forKey: Keys.torchMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.torchMode = TorchMode(rawValue: defaults.string(forKey: Keys.torchMode) ?? "") ?? .auto
    }

    var openGTINQueryID: String {
        get {
            let value = defaults.string(forKey: Keys.queryID) ?? ""
            return value.isEmpty ? Self.defaultOpenGTINQueryID : value
        }
        set { defaults.set(newValue, forKey: Keys.queryID) }
    }

    var speakScanResults: Bool {
        get { defaults.object(forKey: Keys.speakResults) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.speakResults) }
    }

    var hapticsEnabled: Bool {
        get { defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.hapticsEnabled) }
    }

    var hasSeenTutorial: Bool {
        get { defaults.bool(forKey: Keys.hasSeenTutorial) }
        set { defaults.set(newValue, forKey: Keys.hasSeenTutorial) }
    }

    /// Whether the user has accepted the terms of use and privacy policy. The
    /// consent dialog on first launch blocks the app until this is `true`.
    var hasAcceptedLegalTerms: Bool {
        get { defaults.bool(forKey: Keys.hasAcceptedLegalTerms) }
        set { defaults.set(newValue, forKey: Keys.hasAcceptedLegalTerms) }
    }

    /// Last torch state the user chose manually; restored in `.remember` mode.
    var torchWasOn: Bool {
        get { defaults.bool(forKey: Keys.torchWasOn) }
        set { defaults.set(newValue, forKey: Keys.torchWasOn) }
    }
}
