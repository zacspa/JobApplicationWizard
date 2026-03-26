import XCTest
import ComposableArchitecture
import JobApplicationShared
@testable import JobApplicationWizardCore

final class ChangeLogTests: XCTestCase {

    let deviceId = "test-device"

    // MARK: - apply(): Basic Operations

    func testApplyAddJob() {
        var jobs: IdentifiedArrayOf<JobApplication> = []
        let job = JobApplication.mock()
        let event = ChangeEvent(deviceId: deviceId, action: .addJob(job))

        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[id: job.id]?.company, "Acme Corp")
    }

    func testApplyDeleteJob() {
        let job = JobApplication.mock()
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        let event = ChangeEvent(deviceId: deviceId, action: .deleteJob(jobId: job.id))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs.count, 0)
    }

    func testApplyUpdateStatus() {
        let job = JobApplication.mock(status: .wishlist)
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        let event = ChangeEvent(deviceId: deviceId, action: .updateJobStatus(jobId: job.id, newStatus: .applied))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.status, .applied)
    }

    func testApplyToggleFavorite() {
        let job = JobApplication.mock(isFavorite: false)
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        let event = ChangeEvent(deviceId: deviceId, action: .toggleFavorite(jobId: job.id, isFavorite: true))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.isFavorite, true)
    }

    func testApplyUpdateJobField() {
        let job = JobApplication.mock(salary: "$100k")
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        let event = ChangeEvent(deviceId: deviceId, action: .updateJobField(jobId: job.id, field: .salary, value: "$150k"))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.salary, "$150k")
    }

    func testApplySetExcitement() {
        let job = JobApplication.mock(excitement: 2)
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        let event = ChangeEvent(deviceId: deviceId, action: .setExcitement(jobId: job.id, excitement: 5))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.excitement, 5)
    }

    // MARK: - apply(): Notes

    func testApplyAddNote() {
        let job = JobApplication.mock()
        var jobs: IdentifiedArrayOf<JobApplication> = [job]
        let note = Note(title: "Follow up", body: "Send thank you email")

        let event = ChangeEvent(deviceId: deviceId, action: .addNote(jobId: job.id, note: note))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.noteCards.count, 1)
        XCTAssertEqual(jobs[id: job.id]?.noteCards.first?.title, "Follow up")
    }

    func testApplyDeleteNote() {
        let note = Note(title: "Old note", body: "Delete me")
        let job = JobApplication.mock(noteCards: [note])
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        let event = ChangeEvent(deviceId: deviceId, action: .deleteNote(jobId: job.id, noteId: note.id))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.noteCards.count, 0)
    }

    // MARK: - apply(): Contacts

    func testApplyAddContact() {
        let job = JobApplication.mock()
        var jobs: IdentifiedArrayOf<JobApplication> = [job]
        let contact = Contact(name: "Bob", title: "Hiring Manager")

        let event = ChangeEvent(deviceId: deviceId, action: .addContact(jobId: job.id, contact: contact))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.contacts.count, 1)
        XCTAssertEqual(jobs[id: job.id]?.contacts.first?.name, "Bob")
    }

    // MARK: - apply(): Tasks

    func testApplyAddAndToggleTask() {
        let job = JobApplication.mock()
        var jobs: IdentifiedArrayOf<JobApplication> = [job]
        let task = SubTask(title: "Submit application", forStatus: .applied)

        let addEvent = ChangeEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 100),
            deviceId: deviceId,
            action: .addTask(jobId: job.id, task: task)
        )
        let toggleEvent = ChangeEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 200),
            deviceId: deviceId,
            action: .toggleTask(jobId: job.id, taskId: task.id, isCompleted: true)
        )
        ChangeLog.apply(events: [addEvent, toggleEvent], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.tasks.count, 1)
        XCTAssertEqual(jobs[id: job.id]?.tasks.first?.isCompleted, true)
    }

    // MARK: - apply(): Contacts (delete)

    func testApplyDeleteContact() {
        let contact = Contact(name: "Alice", title: "Recruiter")
        let job = JobApplication.mock(contacts: [contact])
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        let event = ChangeEvent(deviceId: deviceId, action: .deleteContact(jobId: job.id, contactId: contact.id))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.contacts.count, 0)
    }

    // MARK: - apply(): Interviews

    func testApplyAddInterview() {
        let job = JobApplication.mock()
        var jobs: IdentifiedArrayOf<JobApplication> = [job]
        let interview = InterviewRound(round: 1, type: "Phone Screen", date: Date(), interviewers: "Bob")

        let event = ChangeEvent(deviceId: deviceId, action: .addInterview(jobId: job.id, interview: interview))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.interviews.count, 1)
        XCTAssertEqual(jobs[id: job.id]?.interviews.first?.type, "Phone Screen")
    }

    func testApplyDeleteInterview() {
        let interview = InterviewRound(round: 1, type: "Technical")
        let job = JobApplication.mock(interviews: [interview])
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        let event = ChangeEvent(deviceId: deviceId, action: .deleteInterview(jobId: job.id, interviewId: interview.id))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.interviews.count, 0)
    }

    // MARK: - apply(): Tasks (delete)

    func testApplyDeleteTask() {
        let task = SubTask(title: "Send resume", forStatus: .applied)
        let job = JobApplication.mock(tasks: [task])
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        let event = ChangeEvent(deviceId: deviceId, action: .deleteTask(jobId: job.id, taskId: task.id))
        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs[id: job.id]?.tasks.count, 0)
    }

    // MARK: - apply(): All JobField variants

    func testApplyUpdateAllJobFields() {
        let job = JobApplication.mock()
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        let fields: [(JobField, String, KeyPath<JobApplication, String>)] = [
            (.company, "NewCo", \.company),
            (.title, "Senior Dev", \.title),
            (.url, "https://new.com", \.url),
            (.salary, "$200k", \.salary),
            (.location, "NYC", \.location),
        ]

        for (i, (field, value, keyPath)) in fields.enumerated() {
            let event = ChangeEvent(
                timestamp: Date(timeIntervalSinceReferenceDate: Double(i) * 100),
                deviceId: deviceId,
                action: .updateJobField(jobId: job.id, field: field, value: value)
            )
            ChangeLog.apply(events: [event], to: &jobs)
            XCTAssertEqual(jobs[id: job.id]?[keyPath: keyPath], value, "Field \(field) not updated")
        }
    }

    // MARK: - apply(): Settings

    func testApplyUpdateSettingsIsNoOpOnJobs() {
        let job = JobApplication.mock()
        var jobs: IdentifiedArrayOf<JobApplication> = [job]
        var settings = AppSettings()
        settings.autoProcessDocuments = true

        let event = ChangeEvent(deviceId: deviceId, action: .updateSettings(settings))
        ChangeLog.apply(events: [event], to: &jobs)

        // Settings events are skipped during job apply; they're handled separately
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[id: job.id]?.company, "Acme Corp")
    }

    // MARK: - apply(): Labels

    func testApplyAddAndRemoveLabel() {
        let job = JobApplication.mock()
        var jobs: IdentifiedArrayOf<JobApplication> = [job]
        let label = JobLabel(name: "Remote", colorHex: "#34C759")

        let addEvent = ChangeEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 100),
            deviceId: deviceId,
            action: .addLabel(jobId: job.id, label: label)
        )
        ChangeLog.apply(events: [addEvent], to: &jobs)
        XCTAssertEqual(jobs[id: job.id]?.labels.count, 1)

        let removeEvent = ChangeEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 200),
            deviceId: deviceId,
            action: .removeLabel(jobId: job.id, labelId: label.id)
        )
        ChangeLog.apply(events: [removeEvent], to: &jobs)
        XCTAssertEqual(jobs[id: job.id]?.labels.count, 0)
    }

    // MARK: - apply(): Ordering and Idempotency

    func testEventsApplyInTimestampOrder() {
        let job = JobApplication.mock(status: .wishlist)
        var jobs: IdentifiedArrayOf<JobApplication> = [job]

        // Create events out of order; apply should sort by timestamp
        let laterEvent = ChangeEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 200),
            deviceId: deviceId,
            action: .updateJobStatus(jobId: job.id, newStatus: .interview)
        )
        let earlierEvent = ChangeEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 100),
            deviceId: deviceId,
            action: .updateJobStatus(jobId: job.id, newStatus: .applied)
        )

        // Pass later event first; apply should still process earlier first
        ChangeLog.apply(events: [laterEvent, earlierEvent], to: &jobs)

        // Last writer wins: interview (timestamp 200) overwrites applied (timestamp 100)
        XCTAssertEqual(jobs[id: job.id]?.status, .interview)
    }

    func testDuplicateAddJobIsIdempotent() {
        var jobs: IdentifiedArrayOf<JobApplication> = []
        let job = JobApplication.mock()
        let event = ChangeEvent(deviceId: deviceId, action: .addJob(job))

        ChangeLog.apply(events: [event, event], to: &jobs)

        XCTAssertEqual(jobs.count, 1)
    }

    func testDeleteNonexistentJobIsNoOp() {
        var jobs: IdentifiedArrayOf<JobApplication> = []
        let event = ChangeEvent(deviceId: deviceId, action: .deleteJob(jobId: UUID()))

        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs.count, 0)
    }

    func testUpdateNonexistentJobIsNoOp() {
        var jobs: IdentifiedArrayOf<JobApplication> = []
        let event = ChangeEvent(deviceId: deviceId, action: .updateJobStatus(jobId: UUID(), newStatus: .offer))

        ChangeLog.apply(events: [event], to: &jobs)

        XCTAssertEqual(jobs.count, 0)
    }

    // MARK: - apply(): Multi-device Conflict Scenario

    func testConcurrentEditsOnDifferentJobsMergeSafely() {
        let job1 = JobApplication.mock(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            company: "Acme",
            status: .wishlist
        )
        let job2 = JobApplication.mock(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            company: "Globex",
            status: .wishlist
        )
        var jobs: IdentifiedArrayOf<JobApplication> = [job1, job2]

        // Device A changes job1 status
        let eventA = ChangeEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 100),
            deviceId: "device-A",
            action: .updateJobStatus(jobId: job1.id, newStatus: .applied)
        )
        // Device B adds a note to job2
        let noteB = Note(title: "Contacted recruiter")
        let eventB = ChangeEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 110),
            deviceId: "device-B",
            action: .addNote(jobId: job2.id, note: noteB)
        )

        ChangeLog.apply(events: [eventA, eventB], to: &jobs)

        // Both edits preserved
        XCTAssertEqual(jobs[id: job1.id]?.status, .applied)
        XCTAssertEqual(jobs[id: job2.id]?.noteCards.count, 1)
    }

    // MARK: - ChangeLog bookkeeping

    func testUnsyncedEventsFiltersCorrectly() {
        var log = ChangeLog()
        let old = ChangeEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 100),
            deviceId: deviceId,
            action: .deleteJob(jobId: UUID())
        )
        let new = ChangeEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 300),
            deviceId: deviceId,
            action: .deleteJob(jobId: UUID())
        )
        log.append(old)
        log.append(new)
        log.markSynced(through: Date(timeIntervalSinceReferenceDate: 200))

        XCTAssertEqual(log.unsyncedEvents.count, 1)
        XCTAssertEqual(log.unsyncedEvents.first?.id, new.id)
    }
}
