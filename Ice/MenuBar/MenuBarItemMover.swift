//
//  MenuBarItemMover.swift
//  Ice
//

import CoreGraphics
import SwiftUI

class MenuBarItemMover {
    enum MoveError: Error, CustomStringConvertible {
        case noMenuBarManager
        case eventFailure
        case noMouseLocation
        case noMainDisplay
        case noMenuBarWindow
        case notMovable(MenuBarItem)
        case noCurrentWindow(MenuBarItem)

        var description: String {
            switch self {
            case .noMenuBarManager:
                "No menu bar manager"
            case .eventFailure:
                "Failed to create event"
            case .noMouseLocation:
                "No mouse location"
            case .noMainDisplay:
                "No main display"
            case .noMenuBarWindow:
                "No menu bar window"
            case .notMovable(let item):
                "Item \"\(item.displayName)\" is not movable"
            case .noCurrentWindow(let item):
                "No current window for item \"\(item.displayName)\""
            }
        }
    }

    enum MoveDestination {
        case left(of: MenuBarItem)
        case right(of: MenuBarItem)
    }

    private(set) weak var menuBarManager: MenuBarManager?

    init(menuBarManager: MenuBarManager) {
        self.menuBarManager = menuBarManager
    }

    func simpleMove(item: MenuBarItem, to destination: MoveDestination, display: DisplayInfo) async throws {
        guard let menuBarManager else {
            throw MoveError.noMenuBarManager
        }

        guard let originalMouseLocation = CGEvent(source: nil)?.location else {
            throw MoveError.noMouseLocation
        }

        let windows = WindowInfo.getCurrent(option: .optionAll)
        let itemManager = menuBarManager.itemManager

        guard let menuBarWindow = itemManager.getMenuBarWindow(from: windows, for: display) else {
            throw MoveError.noMenuBarWindow
        }

        let items = itemManager.getMenuBarItems(windows: windows, menuBarWindow: menuBarWindow, display: display)
        guard let currentItem = item.firstMatch(in: items) else {
            throw MoveError.noCurrentWindow(item)
        }

        guard currentItem.isMovable else {
            throw MoveError.notMovable(currentItem)
        }

        let startPoint: CGPoint
        let endPoint: CGPoint
        switch destination {
        case .left(let targetItem):
            guard let currentTargetItem = targetItem.firstMatch(in: items) else {
                throw MoveError.noCurrentWindow(targetItem)
            }
            guard currentTargetItem.isMovable else {
                throw MoveError.notMovable(currentTargetItem)
            }
            startPoint = CGPoint(x: currentItem.frame.midX, y: currentItem.frame.midY)
            endPoint = CGPoint(x: currentTargetItem.frame.minX, y: currentTargetItem.frame.midY)
        case .right(let targetItem):
            guard let currentTargetItem = targetItem.firstMatch(in: items) else {
                throw MoveError.noCurrentWindow(targetItem)
            }
            guard currentTargetItem.isMovable else {
                throw MoveError.notMovable(currentTargetItem)
            }
            startPoint = CGPoint(x: currentItem.frame.midX, y: currentItem.frame.midY)
            endPoint = CGPoint(x: currentTargetItem.frame.maxX, y: currentTargetItem.frame.midY)
        }

        let events = [
            CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: startPoint,
                mouseButton: .left
            ),
            CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: endPoint,
                mouseButton: .left
            ),
        ].compactMap { event in
            event
        }

        guard !events.isEmpty else {
            throw MoveError.eventFailure
        }

        events[0].flags = .maskCommand

        CGDisplayHideCursor(display.displayID)
        CGWarpMouseCursorPosition(startPoint)

        for event in events {
            usleep(15_000)
            event.post(tap: .cgSessionEventTap)
            usleep(15_000)
        }

        CGWarpMouseCursorPosition(originalMouseLocation)
        CGDisplayShowCursor(display.displayID)
    }
}
