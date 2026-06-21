//
//  AppSettings.swift
//  Marktlotse
//
//  Small observable wrapper around UserDefaults for app preferences.
//

import Foundation
import SwiftUI

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
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
}
