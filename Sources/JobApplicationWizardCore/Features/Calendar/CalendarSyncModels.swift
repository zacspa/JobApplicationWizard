import Foundation

// MARK: - Interview Key

public struct InterviewKey: Hashable, Sendable {
    public let jobId: UUID
    public let interviewId: UUID

    public init(jobId: UUID, interviewId: UUID) {
        self.jobId = jobId
        self.interviewId = interviewId
    }
}

// MARK: - Calendar Sync Warning

public enum CalendarSyncWarning: Equatable, Sendable {
    case eventMissing
}

// MARK: - Calendar Sync Update

public struct CalendarSyncUpdate: Equatable, Sendable {
    public let jobId: UUID
    public let interviewId: UUID
    public let oldDate: Date?
    public let newDate: Date
    public let jobCompany: String
    public let roundNumber: Int

    public init(jobId: UUID, interviewId: UUID, oldDate: Date?, newDate: Date, jobCompany: String, roundNumber: Int) {
        self.jobId = jobId
        self.interviewId = interviewId
        self.oldDate = oldDate
        self.newDate = newDate
        self.jobCompany = jobCompany
        self.roundNumber = roundNumber
    }
}

// MARK: - Calendar Sync Missing

public struct CalendarSyncMissing: Equatable, Sendable {
    public let jobId: UUID
    public let interviewId: UUID

    public init(jobId: UUID, interviewId: UUID) {
        self.jobId = jobId
        self.interviewId = interviewId
    }
}
