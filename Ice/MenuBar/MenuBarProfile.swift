//
//  MenuBarProfile.swift
//  Ice
//

import Combine
import CoreGraphics

// MARK: - MenuBarProfile

final class MenuBarProfile: ObservableObject {
    @Published var name: String
    @Published var itemConfiguration: MenuBarItemConfiguration

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

    /// Returns the name for the menu bar section that should contain the
    /// given item according to the profile.
    func correctSectionName(for item: MenuBarItemInfo) -> MenuBarSection.Name? {
        if itemConfiguration.visibleItems.contains(item) {
            return .visible
        }
        if itemConfiguration.hiddenItems.contains(item) {
            return .hidden
        }
        if itemConfiguration.alwaysHiddenItems.contains(item) {
            return .alwaysHidden
        }
        return nil
    }

    /// Returns the item info for the section with the given name.
    func itemInfoForSection(withName name: MenuBarSection.Name) -> [MenuBarItemInfo] {
        switch name {
        case .visible:
            itemConfiguration.visibleItems
        case .hidden:
            itemConfiguration.hiddenItems
        case .alwaysHidden:
            itemConfiguration.alwaysHiddenItems
        }
    }
}

extension MenuBarProfile {
    /// Returns the item info representing the items that macOS does not
    /// allow to be moved.
    ///
    /// - Note: This function returns the items in the reverse order that
    ///   they appear in the menu bar.
    static func stationaryItemInfo(menuBarManager: MenuBarManager) -> [MenuBarItemInfo] {
        guard let visibleSection = menuBarManager.section(withName: .visible) else {
            return []
        }
        var allInfo = [MenuBarItemInfo]()
        for item in visibleSection.menuBarItems.reversed() {
            if item.isMovable {
                break
            }
            guard let info = MenuBarItemInfo(item: item) else {
                continue
            }
            allInfo.append(info)
        }
        return allInfo
    }
}

extension MenuBarProfile {
    /// Gets the current menu bar item information, for use in a profile.
    ///
    /// - Parameters:
    ///   - itemManager: The menu bar item manager to use to get the items.
    ///   - display: The display to get the items for.
    static func getCurrentItemInfo(itemManager: MenuBarItemManager, display: DisplayInfo) -> [MenuBarItemInfo] {
        let items = itemManager.getMenuBarItems(for: display, onScreenOnly: false)
        let allInfo: [MenuBarItemInfo] = items.compactMap { item in
            guard
                // immovable items and items owned by Ice should not be included in profiles
                item.isMovable,
                item.owningApplication != .current
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

            return MenuBarItemInfo(item: item)
        }

        // profiles represent items in reversed order from how they appear on screen
        return allInfo.reversed()
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
        let info = getCurrentItemInfo(itemManager: itemManager, display: display)
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

    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            name: container.decode(String.self, forKey: .name),
            itemConfiguration: container.decode(MenuBarItemConfiguration.self, forKey: .itemConfiguration)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(itemConfiguration, forKey: .itemConfiguration)
    }
}
