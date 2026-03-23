import SwiftUI

/// A compact, pill-shaped action button for inline actions (Save PDF, Print, Add, etc.)
/// Replaces `.buttonStyle(.bordered).controlSize(.mini)` throughout the app.
public struct DSActionButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.caption)
            .padding(.horizontal, DS.Spacing.pillH)
            .padding(.vertical, DS.Spacing.pillV)
            .background(DS.Color.controlBackground)
            .foregroundColor(DS.Color.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(DS.Color.border, lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
