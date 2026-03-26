import Foundation

// MARK: - Document Type

public enum DocumentType: String, Codable, Equatable, Sendable {
    case pdf
    case docx
    case rtf
    case txt
    case md

    public var icon: String {
        switch self {
        case .pdf:  return "doc.fill"
        case .docx: return "doc.richtext"
        case .rtf:  return "doc.richtext"
        case .txt:  return "doc.text"
        case .md:   return "doc.text"
        }
    }

    public static func from(extension ext: String) -> DocumentType? {
        switch ext.lowercased() {
        case "pdf": return .pdf
        case "docx": return .docx
        case "rtf": return .rtf
        case "txt": return .txt
        case "md", "markdown": return .md
        default: return nil
        }
    }
}
