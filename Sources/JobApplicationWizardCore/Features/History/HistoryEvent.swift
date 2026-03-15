import Foundation

// MARK: - Agent Writable Field

/// Fields the AI agent is allowed to modify. Explicitly excludes id, dateAdded, chatHistory, documents, etc.
public enum AgentWritableField: String, Codable, CaseIterable, Equatable, Sendable {
    case company
    case title
    case location
    case salary
    case url
    case jobDescription
    case resumeUsed
    case coverLetter
}

// MARK: - History Command

/// A reversible command that captures both old and new values for undo support.
public enum HistoryCommand: Codable, Equatable {
    case updateField(jobId: UUID, field: AgentWritableField, oldValue: String, newValue: String)
    case setStatus(jobId: UUID, old: JobStatus, new: JobStatus)
    case addNote(jobId: UUID, noteId: UUID)
    case deleteNote(jobId: UUID, snapshot: Note)
    case addContact(jobId: UUID, contactId: UUID)
    case deleteContact(jobId: UUID, snapshot: Contact)
    case addInterview(jobId: UUID, interviewId: UUID)
    case deleteInterview(jobId: UUID, snapshot: InterviewRound)
    case addLabel(jobId: UUID, label: JobLabel)
    case removeLabel(jobId: UUID, label: JobLabel)
    case setExcitement(jobId: UUID, old: Int, new: Int)
    case toggleFavorite(jobId: UUID, old: Bool, new: Bool)
    case addJob(jobId: UUID)
    case deleteJob(jobId: UUID, snapshot: JobApplication)
    case addDocument(jobId: UUID, documentId: UUID)
    case deleteDocument(jobId: UUID, snapshot: JobDocument)
    case replaceJob(jobId: UUID, oldSnapshot: JobApplication, newSnapshot: JobApplication)
    case compound([HistoryCommand])

    /// Returns the reversed command (for undo).
    public func reversed() -> HistoryCommand {
        switch self {
        case .updateField(let jobId, let field, let oldValue, let newValue):
            return .updateField(jobId: jobId, field: field, oldValue: newValue, newValue: oldValue)
        case .setStatus(let jobId, let old, let new):
            return .setStatus(jobId: jobId, old: new, new: old)
        case .addNote(let jobId, let noteId):
            // Reversing addNote requires the note snapshot; caller must handle
            return .addNote(jobId: jobId, noteId: noteId)
        case .deleteNote(let jobId, let snapshot):
            return .addNote(jobId: jobId, noteId: snapshot.id)
        case .addContact(let jobId, let contactId):
            return .addContact(jobId: jobId, contactId: contactId)
        case .deleteContact(let jobId, let snapshot):
            return .addContact(jobId: jobId, contactId: snapshot.id)
        case .addInterview(let jobId, let interviewId):
            return .addInterview(jobId: jobId, interviewId: interviewId)
        case .deleteInterview(let jobId, let snapshot):
            return .addInterview(jobId: jobId, interviewId: snapshot.id)
        case .addLabel(let jobId, let label):
            return .removeLabel(jobId: jobId, label: label)
        case .removeLabel(let jobId, let label):
            return .addLabel(jobId: jobId, label: label)
        case .setExcitement(let jobId, let old, let new):
            return .setExcitement(jobId: jobId, old: new, new: old)
        case .toggleFavorite(let jobId, let old, let new):
            return .toggleFavorite(jobId: jobId, old: new, new: old)
        case .addJob(let jobId):
            // Cannot fully reverse without snapshot; caller must handle
            return .addJob(jobId: jobId)
        case .deleteJob(let jobId, let snapshot):
            return .addJob(jobId: jobId)
        case .addDocument(let jobId, let documentId):
            return .addDocument(jobId: jobId, documentId: documentId)
        case .deleteDocument(let jobId, let snapshot):
            return .addDocument(jobId: jobId, documentId: snapshot.id)
        case .replaceJob(let jobId, let oldSnapshot, let newSnapshot):
            return .replaceJob(jobId: jobId, oldSnapshot: newSnapshot, newSnapshot: oldSnapshot)
        case .compound(let commands):
            return .compound(commands.reversed().map { $0.reversed() })
        }
    }
}

// MARK: - History Event Source

public enum HistoryEventSource: String, Codable, Equatable, Sendable {
    case user
    case agent
    case `import`
    case system
}

// MARK: - History Event

public struct HistoryEvent: Codable, Identifiable, Equatable {
    public var id: UUID
    public var timestamp: Date
    public var label: String
    public var source: HistoryEventSource
    public var command: HistoryCommand

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        label: String,
        source: HistoryEventSource,
        command: HistoryCommand
    ) {
        self.id = id
        self.timestamp = timestamp
        self.label = label
        self.source = source
        self.command = command
    }
}
