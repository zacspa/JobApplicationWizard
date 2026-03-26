import Foundation

// MARK: - Change Event (Event Sourcing)

/// A granular, append-only change event for conflict-free sync.
/// Each event represents a single mutation to the job database.
public struct ChangeEvent: Codable, Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let deviceId: String
    public let action: ChangeAction

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        deviceId: String,
        action: ChangeAction
    ) {
        self.id = id
        self.timestamp = timestamp
        self.deviceId = deviceId
        self.action = action
    }
}

// MARK: - Change Action

/// The set of granular mutations that can be synced.
/// Bulk fields (chatHistory, documents.rawText, jobDescription, coverLetter)
/// are excluded from granular sync to keep events small.
public enum ChangeAction: Codable, Equatable {
    case addJob(JobApplication)
    case deleteJob(jobId: UUID)
    case updateJobStatus(jobId: UUID, newStatus: JobStatus)
    case toggleFavorite(jobId: UUID, isFavorite: Bool)
    case updateJobField(jobId: UUID, field: JobField, value: String)
    case setExcitement(jobId: UUID, excitement: Int)
    case addNote(jobId: UUID, note: Note)
    case deleteNote(jobId: UUID, noteId: UUID)
    case addContact(jobId: UUID, contact: Contact)
    case deleteContact(jobId: UUID, contactId: UUID)
    case addInterview(jobId: UUID, interview: InterviewRound)
    case deleteInterview(jobId: UUID, interviewId: UUID)
    case addTask(jobId: UUID, task: SubTask)
    case toggleTask(jobId: UUID, taskId: UUID, isCompleted: Bool)
    case deleteTask(jobId: UUID, taskId: UUID)
    case addLabel(jobId: UUID, label: JobLabel)
    case removeLabel(jobId: UUID, labelId: UUID)
}

// MARK: - Job Field

/// Fields that can be updated via string value.
public enum JobField: String, Codable, Equatable {
    case company
    case title
    case url
    case salary
    case location
}

// MARK: - Change Log

/// Manages a local append-only log of change events.
public struct ChangeLog: Codable, Equatable {
    public var events: [ChangeEvent]
    public var lastSyncTimestamp: Date?

    public init(events: [ChangeEvent] = [], lastSyncTimestamp: Date? = nil) {
        self.events = events
        self.lastSyncTimestamp = lastSyncTimestamp
    }

    public var unsyncedEvents: [ChangeEvent] {
        guard let lastSync = lastSyncTimestamp else { return events }
        return events.filter { $0.timestamp > lastSync }
    }

    public mutating func append(_ event: ChangeEvent) {
        events.append(event)
    }

    public mutating func markSynced(through timestamp: Date) {
        lastSyncTimestamp = timestamp
    }

    /// Prune events that have already been synced to prevent unbounded growth.
    public mutating func pruneSynced() {
        guard let lastSync = lastSyncTimestamp else { return }
        events.removeAll { $0.timestamp <= lastSync }
    }

    /// Apply events to a job array, returning the updated array.
    /// Pass `excludingDeviceId` to skip events from the current device (e.g. when applying remote events).
    public static func apply(
        events: [ChangeEvent],
        to jobs: inout IdentifiedArrayOf<JobApplication>,
        excludingDeviceId: String? = nil
    ) {
        let filtered = excludingDeviceId != nil
            ? events.filter { $0.deviceId != excludingDeviceId }
            : events
        for event in filtered.sorted(by: { $0.timestamp < $1.timestamp }) {
            switch event.action {
            case .addJob(let job):
                if jobs[id: job.id] == nil {
                    jobs.append(job)
                }
            case .deleteJob(let jobId):
                jobs.remove(id: jobId)
            case .updateJobStatus(let jobId, let newStatus):
                jobs[id: jobId]?.status = newStatus
            case .toggleFavorite(let jobId, let isFavorite):
                jobs[id: jobId]?.isFavorite = isFavorite
            case .updateJobField(let jobId, let field, let value):
                switch field {
                case .company: jobs[id: jobId]?.company = value
                case .title: jobs[id: jobId]?.title = value
                case .url: jobs[id: jobId]?.url = value
                case .salary: jobs[id: jobId]?.salary = value
                case .location: jobs[id: jobId]?.location = value
                }
            case .setExcitement(let jobId, let excitement):
                jobs[id: jobId]?.excitement = excitement
            case .addNote(let jobId, let note):
                guard jobs[id: jobId]?.noteCards.contains(where: { $0.id == note.id }) != true else { break }
                jobs[id: jobId]?.noteCards.append(note)
            case .deleteNote(let jobId, let noteId):
                jobs[id: jobId]?.noteCards.removeAll { $0.id == noteId }
            case .addContact(let jobId, let contact):
                guard jobs[id: jobId]?.contacts.contains(where: { $0.id == contact.id }) != true else { break }
                jobs[id: jobId]?.contacts.append(contact)
            case .deleteContact(let jobId, let contactId):
                jobs[id: jobId]?.contacts.removeAll { $0.id == contactId }
            case .addInterview(let jobId, let interview):
                guard jobs[id: jobId]?.interviews.contains(where: { $0.id == interview.id }) != true else { break }
                jobs[id: jobId]?.interviews.append(interview)
            case .deleteInterview(let jobId, let interviewId):
                jobs[id: jobId]?.interviews.removeAll { $0.id == interviewId }
            case .addTask(let jobId, let task):
                guard jobs[id: jobId]?.tasks.contains(where: { $0.id == task.id }) != true else { break }
                jobs[id: jobId]?.tasks.append(task)
            case .toggleTask(let jobId, let taskId, let isCompleted):
                if let idx = jobs[id: jobId]?.tasks.firstIndex(where: { $0.id == taskId }) {
                    jobs[id: jobId]?.tasks[idx].isCompleted = isCompleted
                }
            case .deleteTask(let jobId, let taskId):
                jobs[id: jobId]?.tasks.removeAll { $0.id == taskId }
            case .addLabel(let jobId, let label):
                guard jobs[id: jobId]?.labels.contains(where: { $0.id == label.id }) != true else { break }
                jobs[id: jobId]?.labels.append(label)
            case .removeLabel(let jobId, let labelId):
                jobs[id: jobId]?.labels.removeAll { $0.id == labelId }
            }
        }
    }

    // MARK: - Persistence

    public func save(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> ChangeLog {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ChangeLog.self, from: data)
    }
}

// Need IdentifiedArray for the apply function
import ComposableArchitecture
