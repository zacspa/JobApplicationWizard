import Foundation
import SwiftUI

// MARK: - Job Status

enum JobStatus: String, Codable, CaseIterable, Identifiable, Equatable {
    case wishlist = "Wishlist"
    case applied = "Applied"
    case phoneScreen = "Phone Screen"
    case interview = "Interview"
    case offer = "Offer"
    case rejected = "Rejected"
    case withdrawn = "Withdrawn"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .wishlist:    return .purple
        case .applied:     return .blue
        case .phoneScreen: return .orange
        case .interview:   return .cyan
        case .offer:       return .green
        case .rejected:    return .red
        case .withdrawn:   return .gray
        }
    }

    var icon: String {
        switch self {
        case .wishlist:    return "star.fill"
        case .applied:     return "paperplane.fill"
        case .phoneScreen: return "phone.fill"
        case .interview:   return "person.2.fill"
        case .offer:       return "checkmark.seal.fill"
        case .rejected:    return "xmark.circle.fill"
        case .withdrawn:   return "arrow.uturn.backward.circle.fill"
        }
    }
}

// MARK: - Label

struct JobLabel: Codable, Identifiable, Hashable, Equatable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String

    static let presets: [JobLabel] = [
        JobLabel(name: "Remote", colorHex: "#34C759"),
        JobLabel(name: "Hybrid", colorHex: "#FF9500"),
        JobLabel(name: "On-Site", colorHex: "#FF3B30"),
        JobLabel(name: "Great Benefits", colorHex: "#5856D6"),
        JobLabel(name: "High Salary", colorHex: "#FFD60A"),
        JobLabel(name: "Dream Job", colorHex: "#FF2D55"),
        JobLabel(name: "Referral", colorHex: "#32ADE6"),
        JobLabel(name: "Startup", colorHex: "#FF6B35"),
        JobLabel(name: "FAANG", colorHex: "#BF5AF2"),
        JobLabel(name: "Contract", colorHex: "#8E8E93"),
    ]

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// MARK: - Contact

struct Contact: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var title: String = ""
    var email: String = ""
    var linkedin: String = ""
    var notes: String = ""
    var connected: Bool = false
}

// MARK: - Interview Round

struct InterviewRound: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var round: Int
    var type: String = ""
    var date: Date? = nil
    var interviewers: String = ""
    var notes: String = ""
    var completed: Bool = false
}

// MARK: - Job Application

struct JobApplication: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var company: String = ""
    var title: String = ""
    var url: String = ""
    var status: JobStatus = .wishlist
    var dateAdded: Date = Date()
    var dateApplied: Date? = nil
    var salary: String = ""
    var location: String = ""
    var jobDescription: String = ""
    var notes: String = ""
    var resumeUsed: String = ""
    var coverLetter: String = ""
    var labels: [JobLabel] = []
    var contacts: [Contact] = []
    var interviews: [InterviewRound] = []
    var isFavorite: Bool = false
    var excitement: Int = 3
    var hasPDF: Bool = false
    var pdfPath: String? = nil

    var displayTitle: String {
        title.isEmpty ? "Untitled Position" : title
    }

    var displayCompany: String {
        company.isEmpty ? "Unknown Company" : company
    }
}

// MARK: - App Settings

struct AppSettings: Codable, Equatable {
    // API key is stored in the system Keychain, not here.
}

// MARK: - AI Action

enum AIAction: String, CaseIterable, Equatable {
    case chat = "Chat"
    case tailorResume = "Tailor Resume"
    case coverLetter = "Cover Letter"
    case interviewPrep = "Interview Prep"
    case analyzeFit = "Analyze Fit"
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    var id: UUID = UUID()
    var role: Role
    var content: String
    var timestamp: Date = Date()

    enum Role: Equatable {
        case user, assistant
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        let components = NSColor(self).usingColorSpace(.sRGB)
        let r = Int((components?.redComponent ?? 0) * 255)
        let g = Int((components?.greenComponent ?? 0) * 255)
        let b = Int((components?.blueComponent ?? 0) * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - String extension

extension String {
    var wordCount: Int {
        components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}

// MARK: - Date extension

extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
