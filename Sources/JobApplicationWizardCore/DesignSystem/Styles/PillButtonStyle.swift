import SwiftUI

public struct PillButtonStyle: ButtonStyle {
    public var isSelected: Bool
    public var tint: Color

    public init(isSelected: Bool = false, tint: Color = .accentColor) {
        self.isSelected = isSelected
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, DS.Spacing.pillH)
            .padding(.vertical, DS.Spacing.pillV)
            .background(isSelected ? tint : DS.Color.controlBackground)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.clear : DS.Color.border,
                    lineWidth: 1
                )
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
