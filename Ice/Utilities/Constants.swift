//
//  Constants.swift
//  Ice
//

import Foundation

enum Constants {
    // swiftlint:disable force_unwrapping
    /// The display name in the app's bundle.
    static let appName = Bundle.main.displayName!

    /// The version string in the app's bundle.
    static let appVersion = Bundle.main.versionString!

    /// The bundle identifier of the app.
    static let bundleIdentifier = Bundle.main.bundleIdentifier!
    // swiftlint:enable force_unwrapping

    /// A user-readable copyright string formatted with non-breaking
    /// spaces for display in the user interface.
    static let copyright: String = "Copyright\u{00A0}©\u{00A0}2024 Jordan\u{00A0}Baird. All\u{00A0}Rights\u{00A0}Reserved." // U+00A0 'NO-BREAK SPACE'

    /// The identifier for the settings window.
    static let settingsWindowID = "SettingsWindow"

    /// The identifier for the permissions window.
    static let permissionsWindowID = "PermissionsWindow"
}
