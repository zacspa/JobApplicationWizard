import Foundation
import ComposableArchitecture
import PDFKit
import AppKit

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

// MARK: - DocumentClient

public struct DocumentClient {
    public var extractText: @Sendable (URL) async throws -> (text: String, filename: String, type: DocumentType, size: Int)

    public init(
        extractText: @escaping @Sendable (URL) async throws -> (text: String, filename: String, type: DocumentType, size: Int)
    ) {
        self.extractText = extractText
    }
}

public enum DocumentExtractionError: LocalizedError {
    case unsupportedFormat(String)
    case extractionFailed(String)
    case fileNotFound

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Unsupported document format: .\(ext)"
        case .extractionFailed(let reason):
            return "Failed to extract text: \(reason)"
        case .fileNotFound:
            return "File not found."
        }
    }
}

extension DocumentClient: DependencyKey {
    public static var liveValue: DocumentClient {
        DocumentClient(
            extractText: { url in
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw DocumentExtractionError.fileNotFound
                }

                let ext = url.pathExtension.lowercased()
                guard let docType = DocumentType.from(extension: ext) else {
                    throw DocumentExtractionError.unsupportedFormat(ext)
                }

                let filename = url.lastPathComponent
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let size = (attrs?[.size] as? Int) ?? 0

                let text: String
                switch docType {
                case .pdf:
                    guard let doc = PDFDocument(url: url),
                          let extracted = doc.string, !extracted.isEmpty else {
                        throw DocumentExtractionError.extractionFailed("Could not read PDF text")
                    }
                    text = extracted

                case .docx, .rtf:
                    let attributed = try NSAttributedString(
                        url: url,
                        options: [:],
                        documentAttributes: nil
                    )
                    text = attributed.string

                case .txt, .md:
                    text = try String(contentsOf: url, encoding: .utf8)
                }

                return (text: text, filename: filename, type: docType, size: size)
            }
        )
    }
}

extension DocumentClient: TestDependencyKey {
    public static let testValue = DocumentClient(
        extractText: unimplemented("\(Self.self).extractText")
    )
}

extension DependencyValues {
    public var documentClient: DocumentClient {
        get { self[DocumentClient.self] }
        set { self[DocumentClient.self] = newValue }
    }
}
