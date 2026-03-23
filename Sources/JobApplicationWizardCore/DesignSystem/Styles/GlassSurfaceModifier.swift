import SwiftUI

public struct GlassSurfaceModifier: ViewModifier {
    public var radius: CGFloat
    public var border: Bool
    public var shadow: DS.ShadowStyle

    public init(radius: CGFloat = DS.Radius.xl, border: Bool = true, shadow: DS.ShadowStyle = DS.Shadow.floating) {
        self.radius = radius
        self.border = border
        self.shadow = shadow
    }

    public func body(content: Content) -> some View {
        content
            .background(DS.Glass.surface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(DS.Color.borderSubtle, lineWidth: border ? 1 : 0)
            )
            .dsShadow(shadow)
    }
}

extension View {
    /// Applies a frosted glass surface with border and shadow.
    public func glassSurface(
        radius: CGFloat = DS.Radius.xl,
        border: Bool = true,
        shadow: DS.ShadowStyle = DS.Shadow.floating
    ) -> some View {
        modifier(GlassSurfaceModifier(radius: radius, border: border, shadow: shadow))
    }
}
