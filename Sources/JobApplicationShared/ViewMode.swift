import Foundation

public enum ViewMode: String, Codable, CaseIterable, Equatable {
    case kanban = "Kanban"
    case list = "List"

    public var icon: String {
        switch self {
        case .kanban: return "square.grid.3x2"
        case .list:   return "list.bullet"
        }
    }
}
