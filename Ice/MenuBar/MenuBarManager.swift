//
//  MenuBarManager.swift
//  Ice
//

import AXSwift
import Combine
import OSLog
import SwiftUI

/// Manager for the state of the menu bar.
final class MenuBarManager: ObservableObject {
    /// All saved menu bar profiles.
    @Published var profiles = [MenuBarProfile]()

    /// The name of the currently active menu bar profile.
    @Published var activeProfileName = MenuBarProfile.defaultProfileName

    /// The maximum X coordinate of the menu bar's main menu.
    @Published private(set) var mainMenuMaxX: CGFloat = 0

    /// The average color of the menu bar.
    @Published var averageColor: CGColor?

    private(set) var sections = [MenuBarSection]()

    private(set) weak var appState: AppState?

    private(set) lazy var itemManager = MenuBarItemManager(menuBarManager: self)

    private(set) lazy var appearanceManager = MenuBarAppearanceManager(menuBarManager: self)

    private var isHidingApplicationMenus = false

    private let encoder = JSONEncoder()

    private let decoder = JSONDecoder()

    private var cancellables = Set<AnyCancellable>()

    /// The currently active menu bar profile.
    var activeProfile: MenuBarProfile? {
        profiles.first { profile in
            profile.name == activeProfileName
        }
    }

    /// Initializes a new menu bar manager instance.
    init(appState: AppState) {
        self.appState = appState
    }

    /// Performs the initial setup of the menu bar.
    func performSetup() {
        loadInitialState()
        initializeSections()
        DispatchQueue.main.async {
            self.initializeProfiles()
            self.configureCancellables()
            self.appearanceManager.performSetup()
        }
    }

    private func loadInitialState() {
        Defaults.ifPresent(key: .activeProfileName, assign: &activeProfileName)
        Defaults.ifPresent(key: .profiles) { array in
            do {
                let data = try PropertyListSerialization.data(fromPropertyList: array, format: .xml, options: 0)
                profiles = try PropertyListDecoder().decode([MenuBarProfile].self, from: data)
            } catch {
                Logger.menuBarManager.error("Error decoding menu bar profiles: \(error)")
            }
        }
    }

    /// Performs the initial setup of the menu bar's section list.
    private func initializeSections() {
        // make sure initialization can only happen once
        guard sections.isEmpty else {
            Logger.menuBarManager.warning("Sections already initialized")
            return
        }

        sections = [
            MenuBarSection(name: .visible),
            MenuBarSection(name: .hidden),
            MenuBarSection(name: .alwaysHidden),
        ]

        // assign the global app state and hide each section
        if let appState {
            for section in sections {
                section.assignAppState(appState)
                section.hide()
            }
        }
    }

    private func initializeProfiles() {
        // if any profiles were decoded, exit early
        guard profiles.isEmpty else {
            return
        }
        // create a new default profile
        if let display = DisplayInfo.main {
            let profile = MenuBarProfile.createDefaultProfile(with: itemManager, display: display)
            profiles.append(profile)
        }
    }

    private func saveProfiles() {
        do {
            let data = try PropertyListEncoder().encode(profiles)
            let array = try PropertyListSerialization.propertyList(from: data, format: nil)
            Defaults.set(array, forKey: .profiles)
        } catch {
            Logger.menuBarManager.error("Error encoding menu bar profiles: \(error)")
        }
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        // handle focusedApp rehide strategy
        NSWorkspace.shared.publisher(for: \.frontmostApplication)
            .sink { [weak self] _ in
                if
                    let self,
                    let appState,
                    case .focusedApp = appState.settingsManager.generalSettingsManager.rehideStrategy,
                    let hiddenSection = section(withName: .hidden)
                {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        hiddenSection.hide()
                    }
                }
            }
            .store(in: &c)

        // update the main menu maxX
        Publishers.CombineLatest(
            NSWorkspace.shared.publisher(for: \.frontmostApplication), 
            NSWorkspace.shared.publisher(for: \.frontmostApplication?.ownsMenuBar)
        )
        .sink { [weak self] frontmostApplication, _ in
            guard
                let self,
                let frontmostApplication
            else {
                return
            }
            do {
                guard
                    let application = Application(frontmostApplication),
                    let menuBar: UIElement = try application.attribute(.menuBar),
                    let children: [UIElement] = try menuBar.arrayAttribute(.children)
                else {
                    mainMenuMaxX = 0
                    return
                }
                mainMenuMaxX = try children.reduce(into: 0) { result, child in
                    if let frame: CGRect = try child.attribute(.frame) {
                        result += frame.width
                    }
                }
            } catch {
                mainMenuMaxX = 0
                Logger.menuBarManager.error("Error updating main menu maxX: \(error)")
            }
        }
        .store(in: &c)

        // hide application menus when a section is shown (if applicable)
        Publishers.MergeMany(sections.map { $0.$isHidden })
            .throttle(for: 0.01, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard
                    let self,
                    let appState,
                    appState.settingsManager.advancedSettingsManager.hideApplicationMenus
                else {
                    return
                }
                if sections.contains(where: { !$0.isHidden }) {
                    guard let display = DisplayInfo.main else {
                        return
                    }

                    let items = itemManager.getMenuBarItems(for: display, onScreenOnly: true)

                    // get the leftmost item on the screen; the application menu should
                    // be hidden if the item's minX is close to the maxX of the menu
                    guard let leftmostItem = items.min(by: { $0.frame.minX < $1.frame.minX }) else {
                        return
                    }

                    // offset the leftmost item's minX by twice its width to give
                    // ourselves a little wiggle room
                    let offsetMinX = leftmostItem.frame.minX - (leftmostItem.frame.width * 2)

                    // if the offset value is less than or equal to the maxX of the
                    // application menu, activate the app to hide the menu
                    if offsetMinX <= mainMenuMaxX {
                        hideApplicationMenus()
                    }
                } else if 
                    isHidingApplicationMenus,
                    appState.settingsWindow?.isVisible == false
                {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.showApplicationMenus()
                    }
                }
            }
            .store(in: &c)

        Timer.publish(every: 3, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateAverageColor()
            }
            .store(in: &c)

        $activeProfileName
            .receive(on: DispatchQueue.main)
            .sink { name in
                Defaults.set(name, forKey: .activeProfileName)
            }
            .store(in: &c)

        $profiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profiles in
                self?.saveProfiles()
            }
            .store(in: &c)

        for profile in profiles {
            profile.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    self?.saveProfiles()
                }
                .store(in: &c)
        }

        // propagate changes from child observable objects
        itemManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &c)
        appearanceManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &c)

        // propagate changes from all sections
        for section in sections {
            section.objectWillChange
                .sink { [weak self] in
                    self?.objectWillChange.send()
                }
                .store(in: &c)
        }

        cancellables = c
    }

    /// Calculates and stores the average color of the area of the
    /// desktop wallpaper behind the menu bar.
    private func updateAverageColor() {
        Task { @MainActor in
            try await ScreenCaptureManager.shared.update()
            guard
                let display = DisplayInfo.main,
                let wallpaper = try await ScreenCaptureManager.shared.desktopWallpaperBelowMenuBar(for: display),
                let color = wallpaper.averageColor(accuracy: .low, algorithm: .simple, options: .ignoreAlpha)
            else {
                return
            }
            if averageColor != color {
                averageColor = color
            }
        }
    }

    /// Shows the right-click menu.
    func showRightClickMenu(at point: CGPoint) {
        let menu = NSMenu(title: Constants.appName)

        let editItem = NSMenuItem(
            title: "Edit Menu Bar Appearance…",
            action: #selector(showAppearanceEditorPopover),
            keyEquivalent: ""
        )
        editItem.target = self
        menu.addItem(editItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "\(Constants.appName) Settings…",
            action: #selector(AppDelegate.openSettingsWindow),
            keyEquivalent: ","
        )
        menu.addItem(settingsItem)

        menu.popUp(positioning: nil, at: point, in: nil)
    }

    func hideApplicationMenus() {
        appState?.activate(withPolicy: .regular)
        isHidingApplicationMenus = true
    }

    func showApplicationMenus() {
        appState?.deactivate(withPolicy: .accessory)
        isHidingApplicationMenus = false
    }

    func toggleApplicationMenus() {
        if isHidingApplicationMenus {
            showApplicationMenus()
        } else {
            hideApplicationMenus()
        }
    }

    /// Shows the appearance editor popover, centered under the menu bar.
    @objc private func showAppearanceEditorPopover() {
        let panel = MenuBarAppearanceEditorPanel()
        panel.orderFrontRegardless()
        panel.showAppearanceEditorPopover()
    }

    /// Returns the menu bar section with the given name.
    func section(withName name: MenuBarSection.Name) -> MenuBarSection? {
        sections.first { $0.name == name }
    }
}

// MARK: MenuBarManager: BindingExposable
extension MenuBarManager: BindingExposable { }

// MARK: - Logger
private extension Logger {
    static let menuBarManager = Logger(category: "MenuBarManager")
}
