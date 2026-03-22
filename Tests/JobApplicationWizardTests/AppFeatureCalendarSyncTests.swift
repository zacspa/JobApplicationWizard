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
            $0.calendarClient.fetchEvents = { _, _ in [] }
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
            $0.continuousClock = ImmediateClock()
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

    // MARK: - Sync via CalendarFeature

    func testPerformSyncUpdatesRescheduledInterviewDate() async {
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

        await store.send(.calendar(.performSync(store.state.jobs)))
        await store.receive(\.calendar.syncCompleted)
        await store.receive(\.calendar.delegate.interviewDatesUpdated) { state in
            XCTAssertEqual(state.jobs[id: self.jobId]?.interviews.first?.date, rescheduledDate)
        }
    }

    func testPerformSyncSetsMissingWarning() async {
        let store = makeStore(originalDate: now) { _ in nil }
        store.exhaustivity = .off

        await store.send(.calendar(.performSync(store.state.jobs)))
        await store.receive(\.calendar.syncCompleted) { state in
            let key = InterviewKey(jobId: self.jobId, interviewId: self.interviewId)
            XCTAssertEqual(state.calendar.syncWarnings[key], .eventMissing)
        }
    }

    func testPerformSyncRecordsHistoryEventForDateChange() async {
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

        await store.send(.calendar(.performSync(store.state.jobs)))
        await store.receive(\.calendar.syncCompleted)
        await store.receive(\.calendar.delegate.interviewDatesUpdated) { state in
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

        await store.send(.calendar(.performSync(store.state.jobs)))
        await store.receive(\.calendar.syncCompleted)
        await store.receive(\.calendar.delegate.interviewDatesUpdated) { state in
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

        await store.send(.calendar(.performSync(store.state.jobs)))
        await store.receive(\.calendar.syncCompleted) { state in
            XCTAssertNotNil(state.calendar.syncToast)
            XCTAssertTrue(state.calendar.syncToast?.contains("Round 1") == true)
            XCTAssertTrue(state.calendar.syncToast?.contains("Acme Corp") == true)
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
            $0.continuousClock = ImmediateClock()
            $0.calendarClient.fetchEvent = { _ in
                CalendarEvent(
                    id: "event-1",
                    title: "Phone Screen",
                    startDate: rescheduledDate,
                    endDate: rescheduledDate.addingTimeInterval(3600),
                    calendarName: "Work",
                    calendarColor: "#FF0000",
                    isAllDay: false
                )
            }
            $0.calendarClient.fetchEvents = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.calendar(.performSync(store.state.jobs)))
        await store.receive(\.calendar.syncCompleted) { state in
            XCTAssertEqual(state.calendar.syncToast, "2 interview dates updated from Calendar")
        }
    }

    // MARK: - Delegate Handlers

    func testEventLinkedDelegateUpdatesJob() async {
        let interviewId = UUID()
        let interview = InterviewRound(id: interviewId, round: 1)
        let job = JobApplication.mock(id: jobId, interviews: [interview])
        var initialState = AppFeature.State()
        initialState.jobs = IdentifiedArray(uniqueElements: [job])
        initialState.selectedJobID = jobId
        initialState.jobDetail = JobDetailFeature.State(job: job)

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        let event = CalendarEvent(
            id: "event-abc",
            title: "Phone Screen",
            startDate: Date(timeIntervalSinceReferenceDate: 10000),
            endDate: Date(timeIntervalSinceReferenceDate: 13600),
            calendarName: "Work",
            calendarColor: "#FF0000",
            isAllDay: false
        )

        await store.send(.calendar(.delegate(.eventLinked(jobId: jobId, interviewId: interviewId, event: event)))) { state in
            XCTAssertEqual(state.jobs[id: self.jobId]?.interviews.first?.calendarEventIdentifier, "event-abc")
            XCTAssertEqual(state.jobs[id: self.jobId]?.interviews.first?.calendarEventTitle, "Phone Screen")
            XCTAssertEqual(state.jobs[id: self.jobId]?.interviews.first?.date, event.startDate)
        }
    }

    func testEventUnlinkedDelegateUpdatesJob() async {
        let interviewId = UUID()
        var interview = InterviewRound(id: interviewId, round: 1)
        interview.calendarEventIdentifier = "event-abc"
        interview.calendarEventTitle = "Phone Screen"
        let job = JobApplication.mock(id: jobId, interviews: [interview])
        var initialState = AppFeature.State()
        initialState.jobs = IdentifiedArray(uniqueElements: [job])
        initialState.selectedJobID = jobId
        initialState.jobDetail = JobDetailFeature.State(job: job)

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.calendar(.delegate(.eventUnlinked(jobId: jobId, interviewId: interviewId)))) { state in
            XCTAssertNil(state.jobs[id: self.jobId]?.interviews.first?.calendarEventIdentifier)
            XCTAssertNil(state.jobs[id: self.jobId]?.interviews.first?.calendarEventTitle)
        }
    }

    func testNeedsJobsForSyncSendsPerformSync() async {
        let round = InterviewRound(id: interviewId, round: 1, date: now, calendarEventIdentifier: eventId)
        let job = JobApplication.mock(id: jobId, company: "Acme Corp", interviews: [round])
        var initialState = AppFeature.State()
        initialState.jobs = IdentifiedArray(uniqueElements: [job])

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
            $0.continuousClock = ImmediateClock()
            $0.calendarClient.fetchEvent = { _ in nil }
            $0.calendarClient.fetchEvents = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.calendar(.delegate(.needsJobsForSync)))
        await store.receive(\.calendar.performSync)
    }
}
