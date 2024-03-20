//
//  MenuBarItemConfiguration.swift
//  Ice
//

// MARK: - MenuBarItemConfiguration

struct MenuBarItemConfiguration {
    var visibleItems: [MenuBarItemInfo]
    var hiddenItems: [MenuBarItemInfo]
    var alwaysHiddenItems: [MenuBarItemInfo]
}

// MARK: Default Configuration
extension MenuBarItemConfiguration {
    static let defaultConfiguration = MenuBarItemConfiguration(
        visibleItems: [.iceIcon],
        hiddenItems: [.newItems],
        alwaysHiddenItems: []
    )
}

// MARK: MenuBarItemConfiguration: Codable
extension MenuBarItemConfiguration: Codable {
    private enum CodingKeys: String, CodingKey {
        case visibleItems = "Visible"
        case hiddenItems = "Hidden"
        case alwaysHiddenItems = "AlwaysHidden"
    }
}

// MARK: - MenuBarItemInfo

struct MenuBarItemInfo: Hashable {
    let namespace: String
    let title: String

    var isSpecial: Bool {
        namespace == Self.specialNamespace
    }

    init(namespace: String, title: String) {
        self.namespace = namespace
        self.title = title
    }

    init?(item: MenuBarItem) {
        guard
            let namespace = item.owningApplication?.bundleIdentifier,
            let title = item.title
        else {
            return nil
        }
        self.init(namespace: namespace, title: title)
    }
}

// MARK: MenuBarItemInfo Constants
extension MenuBarItemInfo {
    /// The namespace for menu bar items owned by Ice.
    static let iceNamespace = Constants.bundleIdentifier

    /// The namespace for special items.
    static let specialNamespace = "{Special}"

    /// Information for an item that represents the Ice icon.
    static let iceIcon = Self(namespace: iceNamespace, title: "IceIcon")

    /// Information for a special item that indicates the location
    /// where new menu bar items should appear.
    static let newItems = Self(namespace: specialNamespace, title: "NewItems")
}

// MARK: MenuBarItemInfo: Codable
extension MenuBarItemInfo: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let components = string.components(separatedBy: "/")
        guard components.count == 2 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Expected 2 components, found \(components.count)"
                )
            )
        }
        self.namespace = components[0]
        self.title = components[1]
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(namespace + "/" + title)
    }
}
