//
//  MenuBarSection.swift
//  Ice
//

import Cocoa
import Combine
import OSLog

/// A representation of a section in a menu bar.
final class MenuBarSection: ObservableObject {
    /// User-visible name that describes a menu bar section.
    enum Name: String, Codable, Hashable {
        case visible = "Visible"
        case hidden = "Hidden"
        case alwaysHidden = "Always Hidden"
    }

    /// User-visible name that describes the section.
    let name: Name

    /// The control item that manages the visibility of the section.
    let controlItem: ControlItem

    /// A Boolean value that indicates whether the section is hidden.
    @Published private(set) var isHidden: Bool

    /// The menu bar items in the section.
    @Published private(set) var menuBarItems = [MenuBarItem]()

    private var rehideTimer: Timer?

    private var rehideMonitor: UniversalEventMonitor?

    private var cancellables = Set<AnyCancellable>()

    private(set) weak var appState: AppState? {
        didSet {
            guard let appState else {
                return
            }
            controlItem.assignAppState(appState)
        }
    }

    weak var menuBarManager: MenuBarManager? {
        appState?.menuBarManager
    }

    init(name: Name, controlItem: ControlItem) {
        self.name = name
        self.controlItem = controlItem
        self.isHidden = controlItem.state == .hideItems
        configureCancellables()
        updateMenuBarItems()
    }

    /// Creates a menu bar section with the given name.
    convenience init(name: Name) {
        let controlItem = switch name {
        case .visible:
            ControlItem(identifier: .iceIcon)
        case .hidden:
            ControlItem(identifier: .hidden)
        case .alwaysHidden:
            ControlItem(identifier: .alwaysHidden)
        }
        self.init(name: name, controlItem: controlItem)
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        Timer.publish(every: 5, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMenuBarItems()
            }
            .store(in: &c)

        controlItem.$state
            .sink { [weak self] state in
                self?.isHidden = state == .hideItems
            }
            .store(in: &c)

        // propagate changes from the section's control item
        controlItem.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &c)

        cancellables = c
    }

    private func updateMenuBarItems() {
        guard 
            controlItem.isVisible,
            let menuBarManager,
            let activeProfile = menuBarManager.activeProfile,
            let display = DisplayInfo.main
        else {
            return
        }

        var itemInfo = switch name {
        case .visible:
            activeProfile.itemConfiguration.visibleItems
        case .hidden:
            activeProfile.itemConfiguration.hiddenItems
        case .alwaysHidden:
            activeProfile.itemConfiguration.alwaysHiddenItems
        }
        itemInfo.reverse()

        let items = menuBarManager.itemManager.getMenuBarItems(for: display, onScreenOnly: false)
        var menuBarItems = itemInfo.compactMap { info in
            items.first { item in
                item.owningApplication?.bundleIdentifier == info.namespace &&
                item.title == info.title
            }
        }

        if case .visible = name {
            let filtered = items.filter { item in
                !item.acceptsMouseEvents
            }
            menuBarItems.append(contentsOf: filtered)
        }

        self.menuBarItems = menuBarItems
    }

    /// Assigns the section's app state.
    func assignAppState(_ appState: AppState) {
        guard self.appState == nil else {
            Logger.menuBarSection.warning("Multiple attempts made to assign app state")
            return
        }
        self.appState = appState
    }

    /// Shows the status items in the section.
    func show() {
        guard let menuBarManager else {
            return
        }
        switch name {
        case .visible:
            guard let hiddenSection = menuBarManager.section(withName: .hidden) else {
                return
            }
            controlItem.state = .showItems
            hiddenSection.controlItem.state = .showItems
        case .hidden:
            guard let visibleSection = menuBarManager.section(withName: .visible) else {
                return
            }
            controlItem.state = .showItems
            visibleSection.controlItem.state = .showItems
        case .alwaysHidden:
            guard
                let hiddenSection = menuBarManager.section(withName: .hidden),
                let visibleSection = menuBarManager.section(withName: .visible)
            else {
                return
            }
            controlItem.state = .showItems
            hiddenSection.controlItem.state = .showItems
            visibleSection.controlItem.state = .showItems
        }
        startRehideChecks()
    }

    /// Hides the status items in the section.
    func hide() {
        guard let menuBarManager else {
            return
        }
        switch name {
        case .visible:
            guard
                let hiddenSection = menuBarManager.section(withName: .hidden),
                let alwaysHiddenSection = menuBarManager.section(withName: .alwaysHidden)
            else {
                return
            }
            controlItem.state = .hideItems
            hiddenSection.controlItem.state = .hideItems
            alwaysHiddenSection.controlItem.state = .hideItems
        case .hidden:
            guard
                let visibleSection = menuBarManager.section(withName: .visible),
                let alwaysHiddenSection = menuBarManager.section(withName: .alwaysHidden)
            else {
                return
            }
            controlItem.state = .hideItems
            visibleSection.controlItem.state = .hideItems
            alwaysHiddenSection.controlItem.state = .hideItems
        case .alwaysHidden:
            controlItem.state = .hideItems
        }
        appState?.showOnHoverPreventedByUserInteraction = false
        stopRehideChecks()
    }

    /// Toggles the visibility of the status items in the section.
    func toggle() {
        switch controlItem.state {
        case .hideItems: show()
        case .showItems: hide()
        }
    }

    private func startRehideChecks() {
        rehideTimer?.invalidate()
        rehideMonitor?.stop()

        guard
            let appState = menuBarManager?.appState,
            appState.settingsManager.generalSettingsManager.autoRehide,
            case .timed = appState.settingsManager.generalSettingsManager.rehideStrategy
        else {
            return
        }

        rehideMonitor = UniversalEventMonitor(mask: .mouseMoved) { [weak self] event in
            guard
                let self,
                let screen = NSScreen.main
            else {
                return event
            }
            if NSEvent.mouseLocation.y < screen.visibleFrame.maxY {
                if rehideTimer == nil {
                    rehideTimer = .scheduledTimer(
                        withTimeInterval: appState.settingsManager.generalSettingsManager.rehideInterval,
                        repeats: false
                    ) { [weak self] _ in
                        guard
                            let self,
                            let screen = NSScreen.main
                        else {
                            return
                        }
                        if NSEvent.mouseLocation.y < screen.visibleFrame.maxY {
                            hide()
                        } else {
                            startRehideChecks()
                        }
                    }
                }
            } else {
                rehideTimer?.invalidate()
                rehideTimer = nil
            }
            return event
        }

        rehideMonitor?.start()
    }

    private func stopRehideChecks() {
        rehideTimer?.invalidate()
        rehideMonitor?.stop()
        rehideTimer = nil
        rehideMonitor = nil
    }
}

// MARK: MenuBarSection: BindingExposable
extension MenuBarSection: BindingExposable { }

// MARK: - Logger
private extension Logger {
    static let menuBarSection = Logger(category: "MenuBarSection")
}
