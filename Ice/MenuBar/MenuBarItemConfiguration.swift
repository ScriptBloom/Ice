//
//  MenuBarItemConfiguration.swift
//  Ice
//

struct MenuBarItemConfiguration: Codable {
    var visibleItems = [MenuBarItem]()
    var hiddenItems = [MenuBarItem]()
    var alwaysHiddenItems = [MenuBarItem]()
    var newItemSection = MenuBarSection.Name.hidden
}
