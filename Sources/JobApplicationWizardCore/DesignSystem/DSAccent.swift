import SwiftUI

// MARK: - Lane Accent Environment Key

/// The contextual accent color for the current lane/status.
/// Used by DSOutlinedField and other components to tint focus states.
private struct DSLaneAccentKey: EnvironmentKey {
    static let defaultValue: Color = .accentColor
}

public extension EnvironmentValues {
    var dsLaneAccent: Color {
        get { self[DSLaneAccentKey.self] }
        set { self[DSLaneAccentKey.self] = newValue }
    }
}
