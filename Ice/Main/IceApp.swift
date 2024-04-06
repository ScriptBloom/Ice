//
//  IceApp.swift
//  Ice
//

import SwiftUI

@main
struct IceApp: App {
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    @ObservedObject var appState = AppState.shared
    @Environment(\.openWindow) private var openWindow

    init() {
        NSSplitViewItem.swizzle()
    }

    var body: some Scene {
        SettingsWindow(appState: appState, onAppear: {
            if !appState.permissionsManager.hasPermission {
                openWindow(id: Constants.permissionsWindowID)
            }
        })
        PermissionsWindow(appState: appState, onContinue: {
            appState.performSetup()
            openWindow(id: Constants.settingsWindowID)
        })
    }
}
