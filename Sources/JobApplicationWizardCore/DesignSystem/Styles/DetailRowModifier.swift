import SwiftUI

/// Applies consistent styling for icon+label detail rows in the Overview tab.
public struct DetailRowModifier: ViewModifier {
    public var showDivider: Bool

    public init(showDivider: Bool = false) {
        self.showDivider = showDivider
    }

    public func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.sm)
            if showDivider {
                Divider()
            }
        }
    }
}

extension View {
    /// Applies the standard detail-row padding with an optional divider below.
    public func detailRow(showDivider: Bool = false) -> some View {
        modifier(DetailRowModifier(showDivider: showDivider))
    }
}
