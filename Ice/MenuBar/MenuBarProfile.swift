//
//  MenuBarProfile.swift
//  Ice
//

import Foundation

// MARK: - MenuBarProfile

struct MenuBarProfile {
    var name: String
    var visibleItems = [MenuBarItemInfo]()
    var hiddenItems = [MenuBarItemInfo]()
    var alwaysHiddenItems = [MenuBarItemInfo]()
}

// MARK: Default Profile
extension MenuBarProfile {
    /// The default menu bar profile.
    static let defaultProfile = MenuBarProfile(
        name: "Default",
        visibleItems: [.iceIcon],
        hiddenItems: [.newItems],
        alwaysHiddenItems: []
    )
}

// MARK: MenuBarProfile: Codable
extension MenuBarProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case visibleItems = "Visible"
        case hiddenItems = "Hidden"
        case alwaysHiddenItems = "AlwaysHidden"
    }
}

// MARK: - MenuBarItemInfo

extension MenuBarProfile {
    struct MenuBarItemInfo {
        let bundleIdentifier: String
        let title: String
        let isSpecial: Bool
    }
}

// MARK: MenuBarItemInfo Constants
extension MenuBarProfile.MenuBarItemInfo {
    /// Information for an item that represents the Ice icon.
    static let iceIcon = Self(bundleIdentifier: Constants.bundleIdentifier, title: "IceIcon", isSpecial: false)

    /// Information for a special item that indicates the location
    /// where new menu bar items should appear.
    static let newItems = Self(bundleIdentifier: "", title: "NewItems", isSpecial: true)
}

// MARK: MenuBarItemInfo: Codable
extension MenuBarProfile.MenuBarItemInfo: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let components = string.components(separatedBy: "/")
        guard components.count == 3 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Expected 3 components, found \(components.count)"
                )
            )
        }
        self.bundleIdentifier = components[1]
        self.title = components[2]
        self.isSpecial = components[0] == "$"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        let components = [
            isSpecial ? "$" : "",
            bundleIdentifier,
            title,
        ]
        try container.encode(components.joined(separator: "/"))
    }
}
