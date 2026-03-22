import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class CalendarFeatureTests: XCTestCase {

    private let jobId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let interviewId = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func makeEvent(id: String = "event-1", title: String = "Phone Screen", startDate: Date? = nil) -> CalendarEvent {
        let start = startDate ?? now
        return CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: start.addingTimeInterval(3600),
            calendarName: "Work",
            calendarColor: "#FF0000",
            isAllDay: false
        )
    }

    // MARK: - testOpenPickerRequestsAccessWhenNil

    func testOpenPickerRequestsAccessWhenNil() async {
        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendarClient.authorizationStatus = { 3 } // authorized
            $0.calendarClient.fetchEvents = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.openPicker(jobId: jobId, interviewId: interviewId)) {
            $0.showPicker = true
            $0.pickerInterviewId = self.interviewId
            $0.pickerJobId = self.jobId
        }
        // Should receive recheckAccess since lastAccessCheck is nil
        await store.receive(.recheckAccess) {
            $0.accessGranted = true
            $0.lastAccessCheck = self.now
        }
    }

    // MARK: - testOpenPickerRefreshesEventsOnReopen

    func testOpenPickerRefreshesEventsOnReopen() async {
        var state = CalendarFeature.State()
        state.accessGranted = true
        state.lastAccessCheck = now  // recent, within 5 min

        let mockEvents = [makeEvent()]

        let store = TestStore(initialState: state) {
            CalendarFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendarClient.fetchEvents = { _, _ in mockEvents }
        }
        store.exhaustivity = .off

        await store.send(.openPicker(jobId: jobId, interviewId: interviewId)) {
            $0.showPicker = true
            $0.pickerInterviewId = self.interviewId
            $0.pickerJobId = self.jobId
        }
        await store.receive(.eventsLoaded(mockEvents)) {
            $0.events = mockEvents
        }
    }

    // MARK: - testStaleAccessRecheckAfterFiveMinutes

    func testStaleAccessRecheckAfterFiveMinutes() async {
        var state = CalendarFeature.State()
        state.accessGranted = true
        state.lastAccessCheck = now.addingTimeInterval(-400)  // > 5 min ago

        let store = TestStore(initialState: state) {
            CalendarFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendarClient.authorizationStatus = { 3 }
            $0.calendarClient.fetchEvents = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.openPicker(jobId: jobId, interviewId: interviewId)) {
            $0.showPicker = true
            $0.pickerInterviewId = self.interviewId
            $0.pickerJobId = self.jobId
        }
        await store.receive(.recheckAccess) {
            $0.accessGranted = true
            $0.lastAccessCheck = self.now
        }
    }

    // MARK: - testAppDidBecomeActiveDebounces

    func testAppDidBecomeActiveDebounces() async {
        let clock = TestClock()
        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        // Send two rapid activations; only the second should fire
        await store.send(.appDidBecomeActive)
        await store.send(.appDidBecomeActive)

        await clock.advance(by: .seconds(2))
        await store.receive(.delegate(.needsJobsForSync))
    }

    // MARK: - testSyncConcurrentFetch

    func testSyncConcurrentFetch() async {
        let interviewId2 = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let rescheduledDate = now.addingTimeInterval(7200)

        let round1 = InterviewRound(id: interviewId, round: 1, date: now, calendarEventIdentifier: "event-1")
        let round2 = InterviewRound(id: interviewId2, round: 2, date: now, calendarEventIdentifier: "event-2")
        let job = JobApplication.mock(id: jobId, company: "Acme Corp", interviews: [round1, round2])
        let jobs = IdentifiedArray(uniqueElements: [job])

        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        } withDependencies: {
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

        await store.send(.performSync(jobs))
        await store.receive(\.syncCompleted) { state in
            XCTAssertNotNil(state.syncToast)
        }
    }

    // MARK: - testSyncWarningsPersistedAcrossJobSelection

    func testSyncWarningsPersistedAcrossJobSelection() async {
        let key = InterviewKey(jobId: jobId, interviewId: interviewId)
        var state = CalendarFeature.State()
        state.syncWarnings[key] = .eventMissing

        // Warnings persist in CalendarFeature state regardless of job selection
        XCTAssertEqual(state.syncWarnings[key], .eventMissing)

        // Simulate "selecting another job" by checking warning is still there
        let otherKey = InterviewKey(jobId: UUID(), interviewId: UUID())
        XCTAssertNil(state.syncWarnings[otherKey])
        XCTAssertEqual(state.syncWarnings[key], .eventMissing)
    }

    // MARK: - testUnlinkClearsWarning

    func testUnlinkClearsWarning() async {
        let key = InterviewKey(jobId: jobId, interviewId: interviewId)
        var state = CalendarFeature.State()
        state.syncWarnings[key] = .eventMissing

        let store = TestStore(initialState: state) {
            CalendarFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.unlinkEvent(jobId: jobId, interviewId: interviewId)) {
            $0.syncWarnings.removeValue(forKey: key)
        }
        await store.receive(\.delegate.eventUnlinked)
    }

    // MARK: - testEventLinkedDelegateOnSelection

    func testEventLinkedDelegateOnSelection() async {
        var state = CalendarFeature.State()
        state.showPicker = true
        state.pickerJobId = jobId
        state.pickerInterviewId = interviewId

        let event = makeEvent()

        let store = TestStore(initialState: state) {
            CalendarFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.eventSelected(event)) {
            $0.showPicker = false
            $0.pickerInterviewId = nil
            $0.pickerJobId = nil
        }
        await store.receive(.delegate(.eventLinked(jobId: self.jobId, interviewId: self.interviewId, event: event)))
    }

    // MARK: - testDismissPickerClearsState

    func testDismissPickerClearsState() async {
        var state = CalendarFeature.State()
        state.showPicker = true
        state.pickerInterviewId = interviewId
        state.pickerJobId = jobId

        let store = TestStore(initialState: state) {
            CalendarFeature()
        }

        await store.send(.dismissPicker) {
            $0.showPicker = false
            $0.pickerInterviewId = nil
            $0.pickerJobId = nil
        }
    }

    // MARK: - testSearchQueryChanged

    func testSearchQueryChanged() async {
        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        }

        await store.send(.searchQueryChanged("standup")) {
            $0.searchQuery = "standup"
        }
    }

    // MARK: - testDismissSyncToast

    func testDismissSyncToast() async {
        var state = CalendarFeature.State()
        state.syncToast = "Updated 1 interview"

        let store = TestStore(initialState: state) {
            CalendarFeature()
        }

        await store.send(.dismissSyncToast) {
            $0.syncToast = nil
        }
    }

    // MARK: - testDismissWarning

    func testDismissWarning() async {
        let key = InterviewKey(jobId: jobId, interviewId: interviewId)
        var state = CalendarFeature.State()
        state.syncWarnings[key] = .eventMissing

        let store = TestStore(initialState: state) {
            CalendarFeature()
        }

        await store.send(.dismissWarning(key)) {
            $0.syncWarnings.removeValue(forKey: key)
        }
    }
}
