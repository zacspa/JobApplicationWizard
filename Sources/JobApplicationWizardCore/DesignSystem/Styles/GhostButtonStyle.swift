import SwiftUI

public struct GhostButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}
