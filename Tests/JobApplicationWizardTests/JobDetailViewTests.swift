import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

/// View-behavior tests for the calendar UI in InterviewRoundRow.
/// These now use CalendarFeature.State since calendar state moved there.
@MainActor
final class JobDetailViewTests: XCTestCase {

    // MARK: - Nil Title Fallback

    func testNilTitleFallback() {
        var round = InterviewRound(round: 1)
        round.calendarEventIdentifier = "event-abc"
        round.calendarEventTitle = nil

        let displayTitle = round.calendarEventTitle ?? "Linked event"
        XCTAssertEqual(displayTitle, "Linked event")
    }

    func testNonNilTitleIsUsedDirectly() {
        var round = InterviewRound(round: 1)
        round.calendarEventIdentifier = "event-abc"
        round.calendarEventTitle = "Phone Screen"

        let displayTitle = round.calendarEventTitle ?? "Linked event"
        XCTAssertEqual(displayTitle, "Phone Screen")
    }

    // MARK: - Picker Visibility Binding Logic (CalendarFeature state)

    func testPickerBindingFalseWhenInterviewIdMismatch() {
        let interviewId1 = UUID()
        let interviewId2 = UUID()
        var state = CalendarFeature.State()
        state.showPicker = true
        state.pickerInterviewId = interviewId1

        let isShownForRow2 = state.showPicker && state.pickerInterviewId == interviewId2
        XCTAssertFalse(isShownForRow2)
    }

    func testPickerBindingTrueWhenInterviewIdMatches() {
        let interviewId = UUID()
        var state = CalendarFeature.State()
        state.showPicker = true
        state.pickerInterviewId = interviewId

        let isShownForRow = state.showPicker && state.pickerInterviewId == interviewId
        XCTAssertTrue(isShownForRow)
    }

    // MARK: - CalendarFeature eventsLoaded

    func testEventsLoadedUpdatesState() async {
        let events = [
            CalendarEvent(
                id: "evt-1",
                title: "Phone Screen",
                startDate: Date(timeIntervalSinceReferenceDate: 10000),
                endDate: Date(timeIntervalSinceReferenceDate: 13600),
                calendarName: "Work",
                calendarColor: "#FF0000",
                isAllDay: false
            ),
            CalendarEvent(
                id: "evt-2",
                title: "Onsite",
                startDate: Date(timeIntervalSinceReferenceDate: 20000),
                endDate: Date(timeIntervalSinceReferenceDate: 27200),
                calendarName: "Work",
                calendarColor: "#0000FF",
                isAllDay: false
            ),
        ]

        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        }

        await store.send(.eventsLoaded(events)) {
            $0.events = events
        }
    }

    // MARK: - openPicker with access denied

    func testOpenPickerWhenAccessDenied() async {
        var state = CalendarFeature.State()
        state.accessGranted = false
        state.lastAccessCheck = Date(timeIntervalSinceReferenceDate: 0)

        let jobId = UUID()
        let interviewId = UUID()

        let store = TestStore(initialState: state) {
            CalendarFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSinceReferenceDate: 100))
            $0.calendarClient.authorizationStatus = { 2 } // denied
            $0.calendarClient.fetchEvents = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.openPicker(jobId: jobId, interviewId: interviewId)) {
            $0.showPicker = true
            $0.pickerInterviewId = interviewId
            $0.pickerJobId = jobId
        }
    }

    // MARK: - openPicker when already granted

    func testOpenPickerWhenAlreadyGrantedSkipsAccessCheck() async {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        var state = CalendarFeature.State()
        state.accessGranted = true
        state.lastAccessCheck = now // recent check, within 5 min

        let jobId = UUID()
        let interviewId = UUID()

        let store = TestStore(initialState: state) {
            CalendarFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendarClient.fetchEvents = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.openPicker(jobId: jobId, interviewId: interviewId)) {
            $0.showPicker = true
            $0.pickerInterviewId = interviewId
            $0.pickerJobId = jobId
        }
    }
}
