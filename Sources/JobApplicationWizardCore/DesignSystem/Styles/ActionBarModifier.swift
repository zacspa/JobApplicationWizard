import SwiftUI

/// Applies consistent styling for the action bar HStack at the top of tab sections
/// (contacts, interviews, documents). Provides horizontal/vertical padding and
/// a controlBackground fill.
public struct ActionBarModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Color.controlBackground)
    }
}

extension View {
    /// Applies the standard action bar style (horizontal/vertical padding, control background).
    public func actionBar() -> some View {
        modifier(ActionBarModifier())
    }
}
