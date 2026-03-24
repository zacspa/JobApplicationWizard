import SwiftUI

extension DS {
    public enum Color {
        // MARK: - Backgrounds

        /// Window/scene background
        public static var windowBackground: SwiftUI.Color { SwiftUI.Color(NSColor.windowBackgroundColor) }
        /// Control/panel background (sidebar, tab bars, input bars)
        public static var controlBackground: SwiftUI.Color { SwiftUI.Color(NSColor.controlBackgroundColor) }
        /// Text input field background
        public static var textBackground: SwiftUI.Color { SwiftUI.Color(NSColor.textBackgroundColor) }

        // MARK: - Text

        public static var textPrimary: SwiftUI.Color { .primary }
        public static var textSecondary: SwiftUI.Color { .secondary }

        // MARK: - Borders & Separators

        public static var border: SwiftUI.Color { .secondary.opacity(Opacity.border) }
        public static var borderSubtle: SwiftUI.Color { .secondary.opacity(Opacity.subtle) }

        // MARK: - Semantic Feedback

        public static var success: SwiftUI.Color { .green }
        public static var warning: SwiftUI.Color { .orange }
        public static var error: SwiftUI.Color { .red }
        public static var info: SwiftUI.Color { .blue }
    }
}

// MARK: - Opacity Scale

extension DS.Color {
    /// Named opacity values replacing scattered magic numbers.
    public enum Opacity {
        /// Barely visible tint for backgrounds: 0.08
        public static let subtle: Double = 0.08
        /// Light wash behind badges, labels, pills: 0.12
        public static let wash: Double = 0.12
        /// Standard tinted background (selected tab, status pill): 0.15
        public static let tint: Double = 0.15
        /// Slightly stronger tint: 0.18
        public static let medium: Double = 0.18
        /// Visible tint (selected label background): 0.25
        public static let strong: Double = 0.25
        /// Border-weight opacity for secondary strokes: 0.3
        public static let border: Double = 0.3
    }
}
