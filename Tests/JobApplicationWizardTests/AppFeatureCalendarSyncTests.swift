import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class AppFeatureCalendarSyncTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let jobId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let interviewId = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private let eventId = "EKEvent-test-123"

    private func makeStore(
        originalDate: Date,
        fetchEvent: @escaping @Sendable (String) async throws -> CalendarEvent?
    ) -> TestStore<AppFeature.State, AppFeature.Action> {
        let round = InterviewRound(
            id: interviewId,
            round: 1,
            date: originalDate,
            calendarEventIdentifier: eventId
        )
        let job = JobApplication.mock(id: jobId, company: "Acme Corp", interviews: [round])
        var initialState = AppFeature.State()
        initialState.jobs = IdentifiedArray(uniqueElements: [job])
        initialState.selectedJobID = jobId
        initialState.jobDetail = JobDetailFeature.State(job: job)

        return TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.calendarClient.fetchEvent = fetchEvent
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
        }
    }

    private func makeCalendarEvent(startDate: Date) -> CalendarEvent {
        CalendarEvent(
            id: eventId,
            title: "Phone Screen",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3600),
            calendarName: "Work",
            calendarColor: "#FF0000",
            isAllDay: false
        )
    }

    // MARK: - Tests

    func testAppDidBecomeActiveUpdatesRescheduledInterviewDate() async {
        let originalDate = now
        let rescheduledDate = now.addingTimeInterval(7200)
        let store = makeStore(originalDate: originalDate) { [rescheduledDate] _ in
            CalendarEvent(
                id: self.eventId,
                title: "Phone Screen",
                startDate: rescheduledDate,
                endDate: rescheduledDate.addingTimeInterval(3600),
                calendarName: "Work",
                calendarColor: "#FF0000",
                isAllDay: false
            )
        }
        store.exhaustivity = .off

        await store.send(.appDidBecomeActive)
        await store.receive(\.calendarSyncCompleted) { state in
            XCTAssertEqual(state.jobs[id: self.jobId]?.interviews.first?.date, rescheduledDate)
        }
    }

    func testAppDidBecomeActiveSetsMissingWarning() async {
        let store = makeStore(originalDate: now) { _ in nil }
        store.exhaustivity = .off

        await store.send(.appDidBecomeActive)
        await store.receive(\.calendarSyncCompleted) { state in
            XCTAssertEqual(state.jobDetail?.calendarSyncWarnings[self.interviewId], .eventMissing)
        }
    }

    func testAppDidBecomeActiveRecordsHistoryEventForDateChange() async {
        let rescheduledDate = now.addingTimeInterval(7200)
        let store = makeStore(originalDate: now) { [rescheduledDate] _ in
            CalendarEvent(
                id: self.eventId,
                title: "Phone Screen",
                startDate: rescheduledDate,
                endDate: rescheduledDate.addingTimeInterval(3600),
                calendarName: "Work",
                calendarColor: "#FF0000",
                isAllDay: false
            )
        }
        store.exhaustivity = .off

        await store.send(.appDidBecomeActive)
        await store.receive(\.calendarSyncCompleted) { state in
            XCTAssertEqual(state.undoStack.count, 1)
            guard case .updateInterviewDate(let jId, let iId, _, _) = state.undoStack.first?.command else {
                XCTFail("Expected updateInterviewDate command in undoStack")
                return
            }
            XCTAssertEqual(jId, self.jobId)
            XCTAssertEqual(iId, self.interviewId)
        }
    }

    func testUndoCalendarSyncRestoresOldDate() async {
        let originalDate = now
        let rescheduledDate = now.addingTimeInterval(7200)
        let store = makeStore(originalDate: originalDate) { [rescheduledDate] _ in
            CalendarEvent(
                id: self.eventId,
                title: "Phone Screen",
                startDate: rescheduledDate,
                endDate: rescheduledDate.addingTimeInterval(3600),
                calendarName: "Work",
                calendarColor: "#FF0000",
                isAllDay: false
            )
        }
        store.exhaustivity = .off

        await store.send(.appDidBecomeActive)
        await store.receive(\.calendarSyncCompleted) { state in
            XCTAssertEqual(state.jobs[id: self.jobId]?.interviews.first?.date, rescheduledDate)
        }
        await store.send(.undo) { state in
            XCTAssertEqual(state.jobs[id: self.jobId]?.interviews.first?.date, originalDate)
        }
    }

    func testCalendarSyncToastShownForSingleUpdate() async {
        let rescheduledDate = now.addingTimeInterval(7200)
        let store = makeStore(originalDate: now) { [rescheduledDate] _ in
            CalendarEvent(
                id: self.eventId,
                title: "Phone Screen",
                startDate: rescheduledDate,
                endDate: rescheduledDate.addingTimeInterval(3600),
                calendarName: "Work",
                calendarColor: "#FF0000",
                isAllDay: false
            )
        }
        store.exhaustivity = .off

        await store.send(.appDidBecomeActive)
        await store.receive(\.calendarSyncCompleted) { state in
            XCTAssertNotNil(state.calendarSyncToast)
            XCTAssertTrue(state.calendarSyncToast?.contains("Round 1") == true)
            XCTAssertTrue(state.calendarSyncToast?.contains("Acme Corp") == true)
        }
    }

    func testUndoCalendarSyncRestoresNilDateNotDistantPast() async {
        let syncedDate = now.addingTimeInterval(7200)
        let round = InterviewRound(id: interviewId, round: 1, date: nil, calendarEventIdentifier: eventId)
        let job = JobApplication.mock(id: jobId, company: "Acme Corp", interviews: [round])
        var initialState = AppFeature.State()
        initialState.jobs = IdentifiedArray(uniqueElements: [job])
        initialState.selectedJobID = jobId
        initialState.jobDetail = JobDetailFeature.State(job: job)

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.calendarSyncCompleted(
            updates: [CalendarSyncUpdate(jobId: jobId, interviewId: interviewId, oldDate: nil, newDate: syncedDate, jobCompany: "Acme Corp", roundNumber: 1)],
            missing: []
        )) { state in
            XCTAssertEqual(state.jobs[id: self.jobId]?.interviews.first?.date, syncedDate)
        }
        await store.send(.undo) { state in
            XCTAssertNil(state.jobs[id: self.jobId]?.interviews.first?.date, "Undo should restore nil, not distantPast")
        }
    }

    func testUndoCalendarSyncUpdatesJobDetailState() async {
        let originalDate = now
        let rescheduledDate = now.addingTimeInterval(7200)
        let store = makeStore(originalDate: originalDate) { [rescheduledDate] _ in
            CalendarEvent(
                id: self.eventId,
                title: "Phone Screen",
                startDate: rescheduledDate,
                endDate: rescheduledDate.addingTimeInterval(3600),
                calendarName: "Work",
                calendarColor: "#FF0000",
                isAllDay: false
            )
        }
        store.exhaustivity = .off

        await store.send(.appDidBecomeActive)
        await store.receive(\.calendarSyncCompleted) { state in
            XCTAssertEqual(state.jobDetail?.interviews.first?.date, rescheduledDate)
        }
        await store.send(.undo) { state in
            XCTAssertEqual(state.jobDetail?.interviews.first?.date, originalDate)
        }
    }

    func testRapidCalendarSyncCancelsFirstToastDismiss() async {
        let interviewId2 = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let rescheduledDate1 = now.addingTimeInterval(3600)
        let rescheduledDate2 = now.addingTimeInterval(7200)

        let round1 = InterviewRound(id: interviewId, round: 1, date: now, calendarEventIdentifier: "event-1")
        let round2 = InterviewRound(id: interviewId2, round: 2, date: now, calendarEventIdentifier: "event-2")
        let job = JobApplication.mock(id: jobId, company: "Acme Corp", interviews: [round1, round2])
        var initialState = AppFeature.State()
        initialState.jobs = IdentifiedArray(uniqueElements: [job])

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.calendarSyncCompleted(
            updates: [CalendarSyncUpdate(jobId: jobId, interviewId: interviewId, oldDate: now, newDate: rescheduledDate1, jobCompany: "Acme Corp", roundNumber: 1)],
            missing: []
        ))
        // Second sync immediately cancels the first toast dismiss timer
        await store.send(.calendarSyncCompleted(
            updates: [CalendarSyncUpdate(jobId: jobId, interviewId: interviewId2, oldDate: now, newDate: rescheduledDate2, jobCompany: "Acme Corp", roundNumber: 2)],
            missing: []
        )) { state in
            XCTAssertTrue(state.calendarSyncToast?.contains("Round 2") == true)
            XCTAssertTrue(state.calendarSyncToast?.contains("Acme Corp") == true)
        }
    }

    func testCalendarSyncToastCoalescedForMultipleUpdates() async {
        let interviewId2 = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let rescheduledDate = now.addingTimeInterval(7200)

        let round1 = InterviewRound(id: interviewId, round: 1, date: now, calendarEventIdentifier: "event-1")
        let round2 = InterviewRound(id: interviewId2, round: 2, date: now, calendarEventIdentifier: "event-2")
        let job = JobApplication.mock(id: jobId, company: "Acme Corp", interviews: [round1, round2])
        var initialState = AppFeature.State()
        initialState.jobs = IdentifiedArray(uniqueElements: [job])

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.calendarSyncCompleted(
            updates: [
                CalendarSyncUpdate(jobId: jobId, interviewId: interviewId, oldDate: now, newDate: rescheduledDate, jobCompany: "Acme Corp", roundNumber: 1),
                CalendarSyncUpdate(jobId: jobId, interviewId: interviewId2, oldDate: now, newDate: rescheduledDate, jobCompany: "Acme Corp", roundNumber: 2),
            ],
            missing: []
        )) { state in
            XCTAssertEqual(state.calendarSyncToast, "2 interview dates updated from Calendar")
        }
    }
}
