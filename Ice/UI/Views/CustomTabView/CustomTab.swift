//
//  CustomTab.swift
//  Ice
//

import SwiftUI

/// A type that contains the information to construct
/// a tab in a custom tab view.
struct CustomTab {
    /// The tab's label view.
    let label: (Bool) -> AnyView

    /// The tab's content view.
    let content: AnyView

    /// Creates a tab with the given label and content view.
    init<Label: View, Content: View>(
        @ViewBuilder label: @escaping (_ isSelected: Bool) -> Label,
        @ViewBuilder content: () -> Content
    ) {
        self.label = { AnyView(label($0)) }
        self.content = AnyView(content())
    }

    /// Creates a tab with the given label and content view.
    init<Label: View, Content: View>(
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder content: () -> Content
    ) {
        self.label = { _ in AnyView(label()) }
        self.content = AnyView(content())
    }

    /// Creates a tab with the given label and content view.
    init<Content: View>(
        _ labelKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) {
        self.init(label: { _ in Text(labelKey) }, content: content)
    }
}
