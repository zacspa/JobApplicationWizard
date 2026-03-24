import SwiftUI

/// Applies consistent section-header styling used in detail panel tabs.
public struct SectionHeaderModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .font(DS.Typography.heading3)
            .padding(.bottom, DS.Spacing.md)
    }
}

extension View {
    /// Applies the standard section header style (heading3 font, bottom padding).
    public func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderModifier())
    }
}
