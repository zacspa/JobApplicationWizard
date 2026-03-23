import SwiftUI

extension DS {
    /// Predefined material configurations for the frosted glass design language.
    public enum Glass {
        /// Primary floating surfaces: Cuttle panel, toasts
        public static let surface: Material = .ultraThinMaterial
        /// Dense overlays: processing overlay on cards
        public static let overlay: Material = .ultraThinMaterial
        /// Subtle chrome: header bars, input bars, context labels
        public static let chrome: Material = .regularMaterial
    }
}
