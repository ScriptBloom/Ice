//
//  MenuBarSettingsPane.swift
//  Ice
//

import SwiftUI

struct MenuBarSettingsPane: View {
    @AppStorage("MenuBarSettingsPaneSelectedTab")
    var selection: Int = 0

    var body: some View {
        CustomTabView(selection: $selection) {
            CustomTab("Appearance") {
                MenuBarAppearanceTab(location: .settings)
            }
            CustomTab {
                HStack(spacing: 5) {
                    Text("Layout")
                    Text("BETA")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .offset(y: 1)
                }
            } content: {
                MenuBarLayoutTab()
            }
        }
    }
}

#Preview {
    MenuBarSettingsPane()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 300)
}
