//
//  MenuBarItemManager.swift
//  Ice
//

import Cocoa
import Combine
import OSLog

class MenuBarItemManager: ObservableObject {
    /// An error that can be thrown during menu bar item movement.
    enum MoveError: Error {
        case eventFailure
        case noMouseLocation
        case noMainDisplay
        case noMenuBarWindow
        case macOSProhibited(MenuBarItem)
        case noCurrentWindow(MenuBarItem)
    }

    @Published var cachedItemImages = [MenuBarItem.CacheKey: CGImage]()

    private(set) weak var menuBarManager: MenuBarManager?

    private(set) var isArrangingItems = false

    private var cancellables = Set<AnyCancellable>()

    init(menuBarManager: MenuBarManager) {
        self.menuBarManager = menuBarManager
    }

    /// Returns the first menu bar window from the given array of windows
    /// for the given display.
    func getMenuBarWindow(from windows: [WindowInfo], for display: DisplayInfo) -> WindowInfo? {
        windows.first { window in
            window.isOnScreen &&
            display.frame.contains(window.frame) &&
            window.owningApplication == nil &&
            window.windowLayer == kCGMainMenuWindowLevel &&
            window.title == "Menubar"
        }
    }

    /// Returns the first menu bar window for the given display.
    func getMenuBarWindow(for display: DisplayInfo) -> WindowInfo? {
        let windows = WindowInfo.getCurrent(option: .optionOnScreenOnly)
        return getMenuBarWindow(from: windows, for: display)
    }

    /// Returns an array of menu bar items in the given menu bar from the given windows.
    func getMenuBarItems(windows: [WindowInfo], menuBarWindow: WindowInfo, display: DisplayInfo) -> [MenuBarItem] {
        let items = windows.compactMap { window in
            MenuBarItem(itemWindow: window, menuBarWindow: menuBarWindow, display: display)
        }
        return items.sorted { lhs, rhs in
            lhs.frame.maxX < rhs.frame.maxX
        }
    }

    /// Returns an array of menu bar items in the menu bar of the given display.
    func getMenuBarItems(for display: DisplayInfo, onScreenOnly: Bool) -> [MenuBarItem] {
        let windows = WindowInfo.getCurrent(option: onScreenOnly ? .optionOnScreenOnly : .optionAll)
        guard let menuBarWindow = getMenuBarWindow(from: windows, for: display) else {
            return []
        }
        return getMenuBarItems(windows: windows, menuBarWindow: menuBarWindow, display: display)
    }

    func move(item: MenuBarItem, to xPosition: CGFloat) async throws {
        guard item.isMovable else {
            throw MoveError.macOSProhibited(item)
        }
        guard let originalMouseLocation = CGEvent(source: nil)?.location else {
            throw MoveError.noMouseLocation
        }
        guard let mainDisplay = DisplayInfo.main else {
            throw MoveError.noMainDisplay
        }

        let windows = WindowInfo.getCurrent(option: .optionAll)
        guard let menuBarWindow = getMenuBarWindow(from: windows, for: mainDisplay) else {
            throw MoveError.noMenuBarWindow
        }

        // make sure we're working with the current window information
        let items = getMenuBarItems(windows: windows, menuBarWindow: menuBarWindow, display: mainDisplay)
        guard let currentItem = items.first(where: { $0.windowID == item.windowID }) else {
            throw MoveError.noCurrentWindow(item)
        }

        // start at the center of the window
        let startPoint = CGPoint(x: currentItem.frame.midX, y: currentItem.frame.midY)
        // end at the provided X position, centered vertically in the menu bar's frame
        let endPoint = CGPoint(x: mainDisplay.frame.maxX - xPosition, y: menuBarWindow.frame.midY)

        // no need to move if we're already there
        guard startPoint != endPoint else {
            return
        }

        // to move the item, we simulate a mouse drag from the item's current location
        // to the new location while holding down the command key
        print(startPoint)
        let source = CGEventSource(stateID: .hidSystemState)
        let events = Array(compacting: [
            CheckedEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDown,
                fallbackMouseType: .leftMouseUp,
                mouseCursorPosition: startPoint,
                mouseButton: .center,
                flags: .maskCommand
            ),
            CheckedEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDragged,
                fallbackMouseType: .leftMouseUp,
                mouseCursorPosition: endPoint,
                mouseButton: .left,
                flags: []
            ),
            CheckedEvent(
                mouseEventSource: source,
                mouseType: .leftMouseUp,
                fallbackMouseType: .leftMouseUp,
                mouseCursorPosition: endPoint,
                mouseButton: .left,
                flags: []
            ),
        ])

        guard !events.isEmpty else {
            throw MoveError.eventFailure
        }

        CGAssociateMouseAndMouseCursorPosition(0)

        // hide the cursor and move it to the start position
//        CGDisplayHideCursor(CGMainDisplayID())
        CGWarpMouseCursorPosition(startPoint)

        defer {
            // move the cursor back to its original location and show it
            CGWarpMouseCursorPosition(originalMouseLocation)
//            CGDisplayShowCursor(CGMainDisplayID())
            CGAssociateMouseAndMouseCursorPosition(1)
        }

        for event in events {
            try await event.post(timeout: .milliseconds(100))
        }
    }

    @MainActor
    func arrangeItems() async throws {
        guard
            let menuBarManager,
            let activeProfile = menuBarManager.activeProfile,
            let display = DisplayInfo.main
        else {
            return
        }
        isArrangingItems = true
        defer {
            isArrangingItems = false
        }
        try await Task.sleep(for: .seconds(0.25))
        let items = getMenuBarItems(for: display, onScreenOnly: false)
        var position: CGFloat = 0
        for info in activeProfile.itemConfiguration.visibleItems.reversed() {
            guard let item = items.first(where: { $0.matches(info) }) else {
                continue
            }
            try await move(item: item, to: position)
            position += 1
//            try await Task.sleep(for: .seconds(0.1))
        }
        try await Task.sleep(for: .seconds(0.25))
    }
}

// MARK: - Logger
private extension Logger {
    static let menuBarItemManager = Logger(category: "MenuBarItemManager")
}

extension Array {
    init<C: Collection>(compacting collection: C) where C.Element == Element? {
        self = collection.compactMap { $0 }
    }
}
