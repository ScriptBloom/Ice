//
//  MenuBarProfile.swift
//  Ice
//

import CoreGraphics

// MARK: - MenuBarProfile

final class MenuBarProfile {
    var name: String
    var itemConfiguration: MenuBarItemConfiguration

    init(name: String, itemConfiguration: MenuBarItemConfiguration) {
        self.name = name
        self.itemConfiguration = itemConfiguration
    }

    /// Adds the given items to the section in the profile's configuration
    /// that contains the ``MenuBarItemInfo/newItems`` special item.
    func addItems(_ items: [MenuBarItemInfo]) {
        for keyPath: WritableKeyPath<MenuBarItemConfiguration, _> in [\.visibleItems, \.hiddenItems, \.alwaysHiddenItems] {
            if let index = itemConfiguration[keyPath: keyPath].firstIndex(of: .newItems) {
                itemConfiguration[keyPath: keyPath].insert(contentsOf: items, at: index)
                break
            }
        }
    }
}

extension MenuBarProfile {
    /// Gets the current menu bar item information, for use in a profile.
    ///
    /// - Parameters:
    ///   - itemManager: The menu bar item manager to use to get the items.
    ///   - display: The display to get the items for.
    static func getCurrentMenuBarItemInfo(itemManager: MenuBarItemManager, display: DisplayInfo) -> [MenuBarItemInfo] {
        let items = itemManager.getMenuBarItems(for: display, onScreenOnly: false)
        let info: [MenuBarItemInfo] = items.compactMap { item in
            guard
                // immovable items and items owned by Ice should not be included in profiles
                item.acceptsMouseEvents,
                item.owningApplication != .current,
                // items without a bundle identifier or title should not be included in profiles
                let namespace = item.owningApplication?.bundleIdentifier,
                let title = item.title
            else {
                return nil
            }

            // assuming the user does not have other menu bar manager apps running, off screen
            // items are either being hidden by Ice or macOS; items hidden by Ice should be
            // included in profiles, and items hidden by macOS should be excluded; they are
            // hidden by macOS if their x origin is greater or equal to the minX of the display
            if !item.isOnScreen && item.frame.origin.x >= display.frame.minX {
                return nil
            }

            return MenuBarItemInfo(namespace: namespace, title: title)
        }

        // profiles represent items in reversed order from how they appear on screen
        return info.reversed()
    }
}

// MARK: Default Profile
extension MenuBarProfile {
    /// The name of the default profile.
    static let defaultProfileName = "Default"

    /// Creates the default menu bar profile using the given menu bar
    /// item manager and display to read the current menu bar items.
    static func createDefaultProfile(with itemManager: MenuBarItemManager, display: DisplayInfo) -> MenuBarProfile {
        let profile = MenuBarProfile(name: defaultProfileName, itemConfiguration: .defaultConfiguration)
        let info = getCurrentMenuBarItemInfo(itemManager: itemManager, display: display)
        profile.addItems(info)
        return profile
    }
}

// MARK: MenuBarProfile: Codable
extension MenuBarProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case itemConfiguration = "Items"
    }
}
