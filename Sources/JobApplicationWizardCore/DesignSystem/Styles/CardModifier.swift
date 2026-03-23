import SwiftUI

public struct CardModifier: ViewModifier {
    public var isSelected: Bool
    public var isHovered: Bool
    public var tintColor: Color?
    public var backgroundColor: Color?

    public init(
        isSelected: Bool = false,
        isHovered: Bool = false,
        tintColor: Color? = nil,
        backgroundColor: Color? = nil
    ) {
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.tintColor = tintColor
        self.backgroundColor = backgroundColor
    }

    private var resolvedBackground: Color {
        let base = backgroundColor ?? DS.Color.controlBackground
        if isSelected {
            return (tintColor ?? .accentColor).opacity(DS.Color.Opacity.wash)
        }
        return base
    }

    private var borderColor: Color {
        if isSelected {
            return tintColor ?? .accentColor
        }
        if isHovered {
            return Color.secondary.opacity(DS.Color.Opacity.border)
        }
        return Color.clear
    }

    public func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .fill(resolvedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .strokeBorder(
                        borderColor,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .dsShadow(DS.Shadow.card)
    }
}

extension View {
    public func cardStyle(
        isSelected: Bool = false,
        isHovered: Bool = false,
        tintColor: Color? = nil,
        backgroundColor: Color? = nil
    ) -> some View {
        modifier(CardModifier(
            isSelected: isSelected,
            isHovered: isHovered,
            tintColor: tintColor,
            backgroundColor: backgroundColor
        ))
    }
}
