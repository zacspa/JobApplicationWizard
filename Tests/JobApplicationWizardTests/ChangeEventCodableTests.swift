import XCTest
import JobApplicationShared
@testable import JobApplicationWizardCore

final class ChangeEventCodableTests: XCTestCase {

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    private func roundTrip(_ action: ChangeAction, file: StaticString = #file, line: UInt = #line) throws {
        let event = ChangeEvent(deviceId: "test", action: action)
        let data = try encoder.encode(event)
        let decoded = try decoder.decode(ChangeEvent.self, from: data)
        XCTAssertEqual(decoded.id, event.id, file: file, line: line)
        XCTAssertEqual(decoded.action, action, file: file, line: line)
        XCTAssertEqual(decoded.deviceId, "test", file: file, line: line)
    }

    // MARK: - Every ChangeAction Case

    func testAddJobRoundTrip() throws {
        let job = JobApplication.mock(
            noteCards: [Note(title: "A")],
            labels: [JobLabel(name: "Remote", colorHex: "#00FF00")],
            contacts: [Contact(name: "Alice")],
            interviews: [InterviewRound(round: 1, type: "Phone")],
            tasks: [SubTask(title: "Apply", forStatus: .applied)]
        )
        try roundTrip(.addJob(job))
    }

    func testDeleteJobRoundTrip() throws {
        try roundTrip(.deleteJob(jobId: UUID()))
    }

    func testUpdateJobStatusRoundTrip() throws {
        for status in JobStatus.allCases {
            try roundTrip(.updateJobStatus(jobId: UUID(), newStatus: status))
        }
    }

    func testToggleFavoriteRoundTrip() throws {
        try roundTrip(.toggleFavorite(jobId: UUID(), isFavorite: true))
        try roundTrip(.toggleFavorite(jobId: UUID(), isFavorite: false))
    }

    func testUpdateJobFieldRoundTrip() throws {
        for field in [JobField.company, .title, .url, .salary, .location] {
            try roundTrip(.updateJobField(jobId: UUID(), field: field, value: "test value"))
        }
    }

    func testSetExcitementRoundTrip() throws {
        try roundTrip(.setExcitement(jobId: UUID(), excitement: 4))
    }

    func testAddNoteRoundTrip() throws {
        let note = Note(title: "Follow up", body: "Send email", tags: ["important"])
        try roundTrip(.addNote(jobId: UUID(), note: note))
    }

    func testDeleteNoteRoundTrip() throws {
        try roundTrip(.deleteNote(jobId: UUID(), noteId: UUID()))
    }

    func testAddContactRoundTrip() throws {
        let contact = Contact(name: "Bob", title: "Recruiter", email: "bob@co.com")
        try roundTrip(.addContact(jobId: UUID(), contact: contact))
    }

    func testDeleteContactRoundTrip() throws {
        try roundTrip(.deleteContact(jobId: UUID(), contactId: UUID()))
    }

    func testAddInterviewRoundTrip() throws {
        let interview = InterviewRound(round: 2, type: "Technical", date: Date(), interviewers: "Alice, Bob")
        try roundTrip(.addInterview(jobId: UUID(), interview: interview))
    }

    func testDeleteInterviewRoundTrip() throws {
        try roundTrip(.deleteInterview(jobId: UUID(), interviewId: UUID()))
    }

    func testAddTaskRoundTrip() throws {
        let task = SubTask(title: "Prepare resume", forStatus: .applied)
        try roundTrip(.addTask(jobId: UUID(), task: task))
    }

    func testToggleTaskRoundTrip() throws {
        try roundTrip(.toggleTask(jobId: UUID(), taskId: UUID(), isCompleted: true))
    }

    func testDeleteTaskRoundTrip() throws {
        try roundTrip(.deleteTask(jobId: UUID(), taskId: UUID()))
    }

    func testAddLabelRoundTrip() throws {
        let label = JobLabel(name: "Hybrid", colorHex: "#FF9500")
        try roundTrip(.addLabel(jobId: UUID(), label: label))
    }

    func testRemoveLabelRoundTrip() throws {
        try roundTrip(.removeLabel(jobId: UUID(), labelId: UUID()))
    }

    func testUpdateSettingsRoundTrip() throws {
        var settings = AppSettings()
        settings.autoProcessDocuments = true
        try roundTrip(.updateSettings(settings))
    }

    // MARK: - ChangeLog Round-Trip

    func testChangeLogRoundTrip() throws {
        var log = ChangeLog()
        log.append(ChangeEvent(deviceId: "A", action: .deleteJob(jobId: UUID())))
        log.append(ChangeEvent(deviceId: "B", action: .toggleFavorite(jobId: UUID(), isFavorite: true)))
        log.markSynced(through: Date())

        let data = try encoder.encode(log)
        let decoded = try decoder.decode(ChangeLog.self, from: data)

        XCTAssertEqual(decoded.events.count, 2)
        XCTAssertNotNil(decoded.lastSyncTimestamp)
    }
}
