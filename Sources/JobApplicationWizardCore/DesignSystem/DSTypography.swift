import SwiftUI

extension DS {
    public enum Typography {
        // MARK: - Display

        public static let displayLarge: Font = .system(size: 60)
        public static let displayMedium: Font = .system(size: 36)
        public static let displaySmall: Font = .system(size: 32)

        // MARK: - Headings

        public static let heading1: Font = .title2.weight(.bold)
        public static let heading2: Font = .title3.weight(.bold)
        public static let heading3: Font = .headline

        // MARK: - Body

        public static let body: Font = .body
        public static let bodyMedium: Font = .body.weight(.medium)
        public static let bodySemibold: Font = .body.weight(.semibold)

        // MARK: - Supporting

        public static let subheadline: Font = .subheadline
        public static let subheadlineSemibold: Font = .subheadline.weight(.semibold)
        public static let caption: Font = .caption
        public static let captionSemibold: Font = .caption.weight(.semibold)
        public static let caption2: Font = .caption2
        public static let footnote: Font = .footnote

        // MARK: - Special

        /// Tiny label text (card labels, context badge)
        public static let micro: Font = .system(size: 9, weight: .medium)
        /// Badge/countdown text
        public static let badge: Font = .system(size: 10, weight: .medium)
    }
}
