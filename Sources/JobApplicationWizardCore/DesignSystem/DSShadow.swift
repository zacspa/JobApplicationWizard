import SwiftUI

extension DS {
    public struct ShadowStyle {
        public let color: SwiftUI.Color
        public let radius: CGFloat
        public let y: CGFloat
    }

    public enum Shadow {
        /// Subtle card shadow (job cards)
        public static let card = ShadowStyle(color: SwiftUI.Color.black.opacity(0.12), radius: 3, y: 1)
        /// Floating panel shadow (Cuttle expanded, popovers)
        public static let floating = ShadowStyle(color: SwiftUI.Color.black.opacity(0.3), radius: 12, y: 4)
        /// No shadow
        public static let noShadow = ShadowStyle(color: SwiftUI.Color.clear, radius: 0, y: 0)
    }
}

extension View {
    public func dsShadow(_ style: DS.ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, y: style.y)
    }
}
