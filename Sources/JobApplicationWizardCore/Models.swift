import Foundation
import SwiftUI

// MARK: - Job Status

public enum JobStatus: String, Codable, CaseIterable, Identifiable, Comparable {
    case wishlist = "Wishlist"
    case applied = "Applied"
    case phoneScreen = "Phone Screen"
    case interview = "Interview"
    case offer = "Offer"
    case rejected = "Rejected"
    case withdrawn = "Withdrawn"

    public var id: String { rawValue }

    public var color: Color {
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

    public var icon: String {
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

    public var suggestedTaskTitles: [String] {
        switch self {
        case .wishlist:    return ["Research the company", "Check salary range", "Save job description"]
        case .applied:     return ["Save application confirmation", "Follow up after 1 week"]
        case .phoneScreen: return ["Research your interviewer", "Prepare elevator pitch", "Confirm call time and format"]
        case .interview:   return ["Prepare STAR answers", "Research company culture", "Send thank-you note after"]
        case .offer:       return ["Review offer details", "Research market salary", "Negotiate or accept"]
        case .rejected, .withdrawn: return []
        }
    }

    private var sortIndex: Int {
        switch self {
        case .wishlist:    0
        case .applied:     1
        case .phoneScreen: 2
        case .interview:   3
        case .offer:       4
        case .rejected:    5
        case .withdrawn:   6
        }
    }

    public static func < (lhs: JobStatus, rhs: JobStatus) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }
}

// MARK: - Label

public struct JobLabel: Codable, Identifiable, Hashable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var colorHex: String

    public static let presets: [JobLabel] = [
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

    public var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    public init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

// MARK: - Note

public struct Note: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var title: String = ""
    public var subtitle: String = ""
    public var body: String = ""
    public var tags: [String] = []
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(id: UUID = UUID(), title: String = "", subtitle: String = "", body: String = "", tags: [String] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Contact

public struct Contact: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var name: String = ""
    public var title: String = ""
    public var email: String = ""
    public var linkedin: String = ""
    public var notes: String = ""
    public var connected: Bool = false

    public init(id: UUID = UUID(), name: String = "", title: String = "", email: String = "", linkedin: String = "", notes: String = "", connected: Bool = false) {
        self.id = id
        self.name = name
        self.title = title
        self.email = email
        self.linkedin = linkedin
        self.notes = notes
        self.connected = connected
    }
}

// MARK: - SubTask

public struct SubTask: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var title: String
    public var isCompleted: Bool = false
    public var forStatus: JobStatus

    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false, forStatus: JobStatus) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.forStatus = forStatus
    }
}

// MARK: - Interview Round

public struct InterviewRound: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var round: Int
    public var type: String = ""
    public var date: Date? = nil
    public var interviewers: String = ""
    public var notes: String = ""
    public var completed: Bool = false
    public var calendarEventIdentifier: String? = nil
    public var calendarEventTitle: String? = nil

    public init(id: UUID = UUID(), round: Int, type: String = "", date: Date? = nil, interviewers: String = "", notes: String = "", completed: Bool = false, calendarEventIdentifier: String? = nil, calendarEventTitle: String? = nil) {
        self.id = id
        self.round = round
        self.type = type
        self.date = date
        self.interviewers = interviewers
        self.notes = notes
        self.completed = completed
        self.calendarEventIdentifier = calendarEventIdentifier
        self.calendarEventTitle = calendarEventTitle
    }
}

// MARK: - Job Document

public struct JobDocument: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var filename: String
    public var documentType: DocumentType
    public var rawText: String
    public var addedAt: Date = Date()
    public var fileSize: Int?
    public var sourcePath: String?

    public init(
        id: UUID = UUID(),
        filename: String,
        documentType: DocumentType,
        rawText: String,
        addedAt: Date = Date(),
        fileSize: Int? = nil,
        sourcePath: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.documentType = documentType
        self.rawText = rawText
        self.addedAt = addedAt
        self.fileSize = fileSize
        self.sourcePath = sourcePath
    }
}

// MARK: - Job Application

public struct JobApplication: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var company: String = ""
    public var title: String = ""
    public var url: String = ""
    public var status: JobStatus = .wishlist
    public var dateAdded: Date = Date()
    public var dateApplied: Date? = nil
    public var salary: String = ""
    public var location: String = ""
    public var jobDescription: String = ""
    public var noteCards: [Note] = []
    public var resumeUsed: String = ""
    public var coverLetter: String = ""
    public var labels: [JobLabel] = []
    public var contacts: [Contact] = []
    public var interviews: [InterviewRound] = []
    public var isFavorite: Bool = false
    public var excitement: Int = 3
    public var hasPDF: Bool = false
    public var pdfPath: String? = nil
    public var chatHistory: [ChatMessage] = []
    public var documents: [JobDocument] = []
    public var tasks: [SubTask] = []

    public var displayTitle: String {
        title.isEmpty ? "Untitled Position" : title
    }

    public var displayCompany: String {
        company.isEmpty ? "Unknown Company" : company
    }

    public var currentTasks: [SubTask] {
        tasks.filter { $0.forStatus == status }
    }

    public var hasIncompleteCurrentTasks: Bool {
        tasks.contains { $0.forStatus == status && !$0.isCompleted }
    }

    public init() {}

    // Custom decoder: tolerates missing keys (all default) and migrates
    // legacy `notes: String` into a noteCard.
    private enum CodingKeys: String, CodingKey {
        case id, company, title, url, status, dateAdded, dateApplied
        case salary, location, jobDescription, noteCards
        case resumeUsed, coverLetter, labels, contacts, interviews
        case isFavorite, excitement, hasPDF, pdfPath, chatHistory, documents, tasks
        case legacyNotes = "notes"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decodeIfPresent(UUID.self,            forKey: .id)           ?? UUID()
        company      = try c.decodeIfPresent(String.self,          forKey: .company)      ?? ""
        title        = try c.decodeIfPresent(String.self,          forKey: .title)        ?? ""
        url          = try c.decodeIfPresent(String.self,          forKey: .url)          ?? ""
        status       = try c.decodeIfPresent(JobStatus.self,       forKey: .status)       ?? .wishlist
        dateAdded    = try c.decodeIfPresent(Date.self,            forKey: .dateAdded)    ?? Date()
        dateApplied  = try c.decodeIfPresent(Date.self,            forKey: .dateApplied)
        salary       = try c.decodeIfPresent(String.self,          forKey: .salary)       ?? ""
        location     = try c.decodeIfPresent(String.self,          forKey: .location)     ?? ""
        jobDescription = try c.decodeIfPresent(String.self,        forKey: .jobDescription) ?? ""
        resumeUsed   = try c.decodeIfPresent(String.self,          forKey: .resumeUsed)   ?? ""
        coverLetter  = try c.decodeIfPresent(String.self,          forKey: .coverLetter)  ?? ""
        labels       = try c.decodeIfPresent([JobLabel].self,      forKey: .labels)       ?? []
        contacts     = try c.decodeIfPresent([Contact].self,       forKey: .contacts)     ?? []
        interviews   = try c.decodeIfPresent([InterviewRound].self, forKey: .interviews)  ?? []
        isFavorite   = try c.decodeIfPresent(Bool.self,            forKey: .isFavorite)   ?? false
        excitement   = try c.decodeIfPresent(Int.self,             forKey: .excitement)   ?? 3
        hasPDF       = try c.decodeIfPresent(Bool.self,            forKey: .hasPDF)       ?? false
        pdfPath      = try c.decodeIfPresent(String.self,          forKey: .pdfPath)
        chatHistory  = try c.decodeIfPresent([ChatMessage].self,   forKey: .chatHistory)  ?? []
        documents    = try c.decodeIfPresent([JobDocument].self,  forKey: .documents)    ?? []
        tasks        = try c.decodeIfPresent([SubTask].self,        forKey: .tasks)        ?? []

        if let cards = try c.decodeIfPresent([Note].self, forKey: .noteCards) {
            noteCards = cards
        } else if let old = try c.decodeIfPresent(String.self, forKey: .legacyNotes), !old.isEmpty {
            noteCards = [Note(title: "Notes", body: old)]
        } else {
            noteCards = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,             forKey: .id)
        try c.encode(company,        forKey: .company)
        try c.encode(title,          forKey: .title)
        try c.encode(url,            forKey: .url)
        try c.encode(status,         forKey: .status)
        try c.encode(dateAdded,      forKey: .dateAdded)
        try c.encodeIfPresent(dateApplied, forKey: .dateApplied)
        try c.encode(salary,         forKey: .salary)
        try c.encode(location,       forKey: .location)
        try c.encode(jobDescription, forKey: .jobDescription)
        try c.encode(noteCards,      forKey: .noteCards)
        try c.encode(resumeUsed,     forKey: .resumeUsed)
        try c.encode(coverLetter,    forKey: .coverLetter)
        try c.encode(labels,         forKey: .labels)
        try c.encode(contacts,       forKey: .contacts)
        try c.encode(interviews,     forKey: .interviews)
        try c.encode(isFavorite,     forKey: .isFavorite)
        try c.encode(excitement,     forKey: .excitement)
        try c.encode(hasPDF,         forKey: .hasPDF)
        try c.encodeIfPresent(pdfPath, forKey: .pdfPath)
        if !chatHistory.isEmpty {
            try c.encode(chatHistory, forKey: .chatHistory)
        }
        if !documents.isEmpty {
            try c.encode(documents, forKey: .documents)
        }
        try c.encode(tasks,          forKey: .tasks)
    }
}

// MARK: - Work Preference

public enum WorkPreference: String, Codable, CaseIterable, Equatable {
    case remote   = "Remote"
    case hybrid   = "Hybrid"
    case onSite   = "On-Site"
    case flexible = "Flexible"
}

// MARK: - User Profile

public struct UserProfile: Codable, Equatable {
    public var name: String = ""
    public var currentTitle: String = ""
    public var location: String = ""
    public var linkedIn: String = ""
    public var website: String = ""
    public var summary: String = ""
    public var targetRoles: [String] = []
    public var skills: [String] = []
    public var preferredSalary: String = ""
    public var workPreference: WorkPreference = .flexible
    public var resume: String = ""
    public var coverLetterTemplate: String = ""

    public init(name: String = "", currentTitle: String = "", location: String = "", linkedIn: String = "", website: String = "", summary: String = "", targetRoles: [String] = [], skills: [String] = [], preferredSalary: String = "", workPreference: WorkPreference = .flexible, resume: String = "", coverLetterTemplate: String = "") {
        self.name = name
        self.currentTitle = currentTitle
        self.location = location
        self.linkedIn = linkedIn
        self.website = website
        self.summary = summary
        self.targetRoles = targetRoles
        self.skills = skills
        self.preferredSalary = preferredSalary
        self.workPreference = workPreference
        self.resume = resume
        self.coverLetterTemplate = coverLetterTemplate
    }
}

// MARK: - AI Provider

public enum AIProvider: String, Codable, CaseIterable, Equatable, Sendable {
    case claudeAPI = "Claude API"
    case acpAgent = "ACP Agent"
}

// MARK: - ACP Connection State (shared across features via @Shared)

public struct ACPConnectionState: Equatable, Sendable {
    public var aiProvider: AIProvider = .acpAgent
    public var isConnecting: Bool = false
    public var isConnected: Bool = false
    public var connectedAgentName: String? = nil
    public var error: String? = nil

    public init() {}
}

// MARK: - App Settings

public struct AppSettings: Codable, Equatable {
    // API key is stored in the system Keychain, not here.
    public var userProfile: UserProfile = UserProfile()
    public var defaultViewMode: ViewMode = .kanban
    public var aiProvider: AIProvider = .acpAgent
    public var selectedACPAgentId: String? = nil
    public var cuttleContext: CuttleContext? = nil
    public var globalChatHistory: [ChatMessage] = []
    public var statusChatHistories: [String: [ChatMessage]] = [:]
    public var agentActionMode: AgentActionMode = .applyImmediately
    public var autoProcessDocuments: Bool = false
    public var hasCuttleOnboardingCompleted: Bool = false

    private enum CodingKeys: String, CodingKey {
        case userProfile, defaultViewMode, aiProvider, selectedACPAgentId
        case cuttleContext, globalChatHistory, statusChatHistories
        case agentActionMode, autoProcessDocuments, hasCuttleOnboardingCompleted
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userProfile          = try c.decodeIfPresent(UserProfile.self,            forKey: .userProfile)          ?? UserProfile()
        defaultViewMode      = try c.decodeIfPresent(ViewMode.self,               forKey: .defaultViewMode)      ?? .kanban
        aiProvider           = try c.decodeIfPresent(AIProvider.self,             forKey: .aiProvider)           ?? .acpAgent
        selectedACPAgentId   = try c.decodeIfPresent(String.self,                 forKey: .selectedACPAgentId)
        cuttleContext        = try c.decodeIfPresent(CuttleContext.self,          forKey: .cuttleContext)
        globalChatHistory    = try c.decodeIfPresent([ChatMessage].self,          forKey: .globalChatHistory)    ?? []
        statusChatHistories  = try c.decodeIfPresent([String: [ChatMessage]].self, forKey: .statusChatHistories) ?? [:]
        agentActionMode      = try c.decodeIfPresent(AgentActionMode.self,        forKey: .agentActionMode)      ?? .applyImmediately
        autoProcessDocuments = try c.decodeIfPresent(Bool.self,                    forKey: .autoProcessDocuments) ?? false
        hasCuttleOnboardingCompleted = try c.decodeIfPresent(Bool.self,            forKey: .hasCuttleOnboardingCompleted) ?? false
    }
}

// MARK: - App Data Export

public struct AppDataExport: Codable, Equatable {
    public static let currentVersion = 1
    public var version: Int = Self.currentVersion
    public var exportedAt: Date = Date()
    public var jobs: [JobApplication]
    public var settings: AppSettings

    public init(jobs: [JobApplication], settings: AppSettings) {
        self.jobs = jobs
        self.settings = settings
    }
}

// MARK: - AI Action

public enum AIAction: String, CaseIterable, Equatable {
    case chat = "Chat"
    case tailorResume = "Tailor Resume"
    case coverLetter = "Cover Letter"
    case interviewPrep = "Interview Prep"
    case analyzeFit = "Analyze Fit"
}

// MARK: - Chat Message

public struct ChatMessage: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var role: Role
    public var content: String
    public var timestamp: Date = Date()

    public enum Role: String, Codable, Equatable {
        case user = "user"
        case assistant = "assistant"
    }

    public init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Color Extension

extension Color {
    public init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    public var hexString: String {
        let components = NSColor(self).usingColorSpace(.sRGB)
        let r = Int((components?.redComponent ?? 0) * 255)
        let g = Int((components?.greenComponent ?? 0) * 255)
        let b = Int((components?.blueComponent ?? 0) * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - String extension

extension String {
    public var wordCount: Int {
        components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}

// MARK: - Date extension

extension Date {
    public var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
