//
//  MenuBarItem.swift
//  Ice
//

import Cocoa

private func bestDisplayName(for window: WindowInfo) -> String {
    guard let application = window.owningApplication else {
        return window.title ?? ""
    }
    var bestName: String {
        application.localizedName ?? application.bundleIdentifier ?? ""
    }
    guard let title = window.title else {
        return bestName
    }
    // by default, use the application name, but handle some special cases
    return switch application.bundleIdentifier {
    case "com.apple.controlcenter":
        if title == "BentoBox" { // Control Center icon
            bestName
        } else if title == "NowPlaying" {
            "Now Playing"
        } else {
            title
        }
    case "com.apple.systemuiserver":
        if title == "TimeMachine.TMMenuExtraHost" {
            "Time Machine"
        } else {
            title
        }
    default:
        bestName
    }
}

/// A type that represents an item in a menu bar.
struct MenuBarItem {
    let windowID: CGWindowID
    let frame: CGRect
    let title: String?
    let owningApplication: NSRunningApplication?
    let isOnScreen: Bool
    let displayName: String
    let acceptsMouseEvents: Bool

    /// Creates a menu bar item.
    ///
    /// The parameters passed into this initializer are verified during the menu
    /// bar item's creation. If `itemWindow` does not represent a menu bar item
    /// in the menu bar represented by `menuBarWindow`, and if `menuBarWindow`
    /// does not represent a menu bar on the display represented by `display`,
    /// the initializer will fail.
    ///
    /// - Parameters:
    ///   - itemWindow: A window that contains information about the item.
    ///   - menuBarWindow: A window that contains information about the item's menu bar.
    ///   - display: The display that contains the item's menu bar.
    init?(itemWindow: WindowInfo, menuBarWindow: WindowInfo, display: DisplayInfo) {
        // verify menuBarWindow
        guard
            menuBarWindow.isOnScreen,
            display.frame.contains(menuBarWindow.frame),
            menuBarWindow.owningApplication == nil,
            menuBarWindow.windowLayer == kCGMainMenuWindowLevel,
            menuBarWindow.title == "Menubar"
        else {
            return nil
        }

        // verify itemWindow
        guard
            itemWindow.windowLayer == kCGStatusWindowLevel,
            itemWindow.frame.minY == menuBarWindow.frame.minY,
            itemWindow.frame.maxY == menuBarWindow.frame.maxY
        else {
            return nil
        }

        let displayName = bestDisplayName(for: itemWindow)
        let disabledDisplayNames = [
            "Clock",
            "Siri",
            "Control Center",
        ]

        self.windowID = itemWindow.windowID
        self.frame = itemWindow.frame
        self.title = itemWindow.title
        self.owningApplication = itemWindow.owningApplication
        self.isOnScreen = itemWindow.isOnScreen
        self.displayName = displayName
        self.acceptsMouseEvents = !disabledDisplayNames.contains(displayName)
    }
}
