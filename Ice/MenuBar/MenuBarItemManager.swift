//
//  MenuBarItemManager.swift
//  Ice
//

import Cocoa
import Combine

class MenuBarItemManager: ObservableObject {
    private(set) weak var menuBarManager: MenuBarManager?

    private var cancellables = Set<AnyCancellable>()

    init(menuBarManager: MenuBarManager) {
        self.menuBarManager = menuBarManager
        configureCancellables()
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        Timer.publish(every: 5, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateProfile()
            }
            .store(in: &c)

        cancellables = c
    }

    /// Returns an array of menu bar items in the menu bar of the given display.
    func getMenuBarItems(for display: DisplayInfo, onScreenOnly: Bool) -> [MenuBarItem] {
        let menuBarWindowPredicate: (WindowInfo) -> Bool = { window in
            window.isOnScreen &&
            display.frame.contains(window.frame) &&
            window.owningApplication == nil &&
            window.windowLayer == kCGMainMenuWindowLevel &&
            window.title == "Menubar"
        }

        let windows = WindowInfo.getCurrent(option: onScreenOnly ? .optionOnScreenOnly : .optionAll)

        guard let menuBarWindow = windows.first(where: menuBarWindowPredicate) else {
            return []
        }

        let items = windows.compactMap { window in
            MenuBarItem(itemWindow: window, menuBarWindow: menuBarWindow, display: display)
        }

        return items.sorted { lhs, rhs in
            lhs.frame.maxX < rhs.frame.maxX
        }
    }

    func updateProfile() {
        guard 
            let menuBarManager,
            let hiddenSection = menuBarManager.section(withName: .hidden),
            let alwaysHiddenSection = menuBarManager.section(withName: .alwaysHidden),
            hiddenSection.isHidden,
            alwaysHiddenSection.isHidden,
            let display = DisplayInfo.main
        else {
            return
        }
        let items = getMenuBarItems(for: display, onScreenOnly: false)
        for section in menuBarManager.sections {
            switch section.name {
            case .visible:
                menuBarManager.activeProfile.visibleItems.removeAll { !$0.isSpecial }
                guard let hiddenControlItem = items.first(where: { $0.windowID == hiddenSection.controlItem.windowID }) else {
                    break
                }
                menuBarManager.activeProfile.visibleItems += items
                    .filter { item in
                        item.acceptsMouseEvents &&
                        item.frame.minX >= hiddenControlItem.frame.maxX
                    }
                    .compactMap { item in
                        guard
                            let namespace = item.owningApplication?.bundleIdentifier,
                            let title = item.title
                        else {
                            return nil
                        }
                        return MenuBarProfile.MenuBarItemInfo(namespace: namespace, title: title)
                    }
                    .reversed()
            case .hidden:
                menuBarManager.activeProfile.hiddenItems.removeAll { !$0.isSpecial }
                guard
                    let hiddenControlItem = items.first(where: { $0.windowID == hiddenSection.controlItem.windowID }),
                    let alwaysHiddenControlItem = items.first(where: { $0.windowID == alwaysHiddenSection.controlItem.windowID })
                else {
                    break
                }
                menuBarManager.activeProfile.hiddenItems += items
                    .filter { item in
                        item.frame.maxX <= hiddenControlItem.frame.minX &&
                        item.frame.minX >= alwaysHiddenControlItem.frame.maxX
                    }
                    .compactMap { item in
                        guard
                            let namespace = item.owningApplication?.bundleIdentifier,
                            let title = item.title
                        else {
                            return nil
                        }
                        return MenuBarProfile.MenuBarItemInfo(namespace: namespace, title: title)
                    }
                    .reversed()
            case .alwaysHidden:
                menuBarManager.activeProfile.alwaysHiddenItems.removeAll { !$0.isSpecial }
                guard let alwaysHiddenControlItem = items.first(where: { $0.windowID == alwaysHiddenSection.controlItem.windowID }) else {
                    break
                }
                menuBarManager.activeProfile.alwaysHiddenItems += items
                    .filter { item in
                        item.frame.maxX <= alwaysHiddenControlItem.frame.minX
                    }
                    .compactMap { item in
                        guard
                            let namespace = item.owningApplication?.bundleIdentifier,
                            let title = item.title
                        else {
                            return nil
                        }
                        return MenuBarProfile.MenuBarItemInfo(namespace: namespace, title: title)
                    }
                    .reversed()
            }
        }
    }
}
