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
}

// MARK: Default Profile
extension MenuBarProfile {
    /// The name of the default profile.
    static let defaultProfileName = "Default"

    /// Creates the default menu bar profile using the given menu bar
    /// item manager and display to read the current menu bar items.
    static func createDefaultProfile(with itemManager: MenuBarItemManager, display: DisplayInfo) -> MenuBarProfile {
        let profile = MenuBarProfile(name: defaultProfileName, itemConfiguration: .defaultConfiguration)
        profile.itemConfiguration.hiddenItems += itemManager
            .getMenuBarItems(for: display, onScreenOnly: false)
            .filter { item in
                item.acceptsMouseEvents &&
                item.owningApplication != .current
            }
            .compactMap { item in
                guard
                    let namespace = item.owningApplication?.bundleIdentifier,
                    let title = item.title
                else {
                    return nil
                }
                return MenuBarItemInfo(namespace: namespace, title: title)
            }
            .reversed()
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
