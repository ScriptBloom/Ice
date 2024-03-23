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

//        Timer.publish(every: 5, on: .main, in: .default)
//            .autoconnect()
//            .sink { [weak self] _ in
//                self?.updateProfile()
//            }
//            .store(in: &c)

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
}
