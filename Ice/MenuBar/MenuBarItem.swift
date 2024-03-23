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

private let disabledDisplayNames = [
    "Clock",
    "Siri",
    "Control Center",
]

// MARK: - MenuBarItem

/// A type that represents an item in a menu bar.
struct MenuBarItem {
    let windowID: CGWindowID
    let frame: CGRect
    let title: String?
    let owningApplication: NSRunningApplication?
    let isOnScreen: Bool
    let displayName: String
    let isMovable: Bool

    /// Creates a menu bar item.
    ///
    /// The parameters passed into this initializer are verified during the
    /// menu bar item's creation. If `itemWindow` does not represent a menu
    /// bar item in the menu bar represented by `menuBarWindow`, and if
    /// `menuBarWindow` does not represent a menu bar on the display
    /// represented by `display`, the initializer will fail.
    ///
    /// - Parameters:
    ///   - itemWindow: A window that contains information about the item.
    ///   - menuBarWindow: A window that contains information about the
    ///     item's menu bar.
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

        self.windowID = itemWindow.windowID
        self.frame = itemWindow.frame
        self.title = itemWindow.title
        self.owningApplication = itemWindow.owningApplication
        self.isOnScreen = itemWindow.isOnScreen
        self.displayName = bestDisplayName(for: itemWindow)
        self.isMovable = !disabledDisplayNames.contains(displayName)
    }

    /// Returns a key to use when caching the item.
    func cacheKey() -> CacheKey {
        CacheKey(
            bundleIdentifier: owningApplication?.bundleIdentifier,
            title: title
        )
    }

    /// Returns a Boolean value that indicates whether this item matches
    /// the given item info.
    func matches(_ info: MenuBarItemInfo) -> Bool {
        owningApplication?.bundleIdentifier == info.namespace &&
        title == info.title
    }
}

// MARK: MenuBarItem: Equatable
extension MenuBarItem: Equatable {
    static func == (lhs: MenuBarItem, rhs: MenuBarItem) -> Bool {
        lhs.windowID == rhs.windowID &&
        NSStringFromRect(lhs.frame) == NSStringFromRect(rhs.frame) &&
        lhs.title == rhs.title &&
        lhs.owningApplication?.bundleIdentifier == rhs.owningApplication?.bundleIdentifier &&
        lhs.isOnScreen == rhs.isOnScreen &&
        lhs.displayName == rhs.displayName &&
        lhs.isMovable == rhs.isMovable
    }
}

// MARK: MenuBarItem: Hashable
extension MenuBarItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(windowID)
        hasher.combine(NSStringFromRect(frame))
        hasher.combine(title)
        hasher.combine(owningApplication?.bundleIdentifier)
        hasher.combine(isOnScreen)
        hasher.combine(displayName)
        hasher.combine(isMovable)
    }
}

// MARK: MenuBarItem.CacheKey
extension MenuBarItem {
    /// A key to use when caching a menu bar item.
    struct CacheKey: Hashable {
        let bundleIdentifier: String?
        let title: String?
    }
}
