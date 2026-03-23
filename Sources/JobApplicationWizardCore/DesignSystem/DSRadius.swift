import SwiftUI

extension DS {
    public enum Radius {
        /// Buttons, input fields, small controls
        public static let small: CGFloat = 6
        /// Cards, sections, stat bubbles
        public static let medium: CGFloat = 8
        /// Kanban rows, swimlanes
        public static let large: CGFloat = 10
        /// Chat bubbles, expanded Cuttle panel
        public static let xl: CGFloat = 12
        /// Cuttle expanded panel
        public static let xxl: CGFloat = 16
    }
}
