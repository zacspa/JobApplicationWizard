import Foundation

// MARK: - Agent Action Mode

public enum AgentActionMode: String, Codable, CaseIterable, Equatable, Sendable {
    case applyImmediately = "Apply Immediately"
    case requireApproval = "Require Approval"
}
