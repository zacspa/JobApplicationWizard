import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

/// View-behavior tests for the calendar UI in InterviewRoundRow.
/// Feature-level reducer tests for calendar actions live in JobDetailFeatureTests.swift.
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

    // MARK: - Access Denied State

    /// When calendarAccessGranted == false and linkCalendarEvent is dispatched anyway,
    /// the reducer still opens the picker (the View prevents showing the button, but
    /// the action itself remains functional).
    func testLinkCalendarEventWhenAccessDeniedStillOpensPicker() async {
        let interviewId = UUID()
        let interview = InterviewRound(id: interviewId, round: 1)
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.calendarAccessGranted = false

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.linkCalendarEvent(interviewId: interviewId)) {
            $0.showCalendarPicker = true
            $0.calendarPickerInterviewId = interviewId
        }
    }

    // MARK: - Picker Visibility Binding Logic

    /// The popover binding uses: showCalendarPicker && calendarPickerInterviewId == round.id.
    /// If showCalendarPicker is true but the id belongs to a different interview,
    /// the picker for this row should NOT be shown (computed binding returns false).
    func testPickerBindingFalseWhenInterviewIdMismatch() {
        let interviewId1 = UUID()
        let interviewId2 = UUID()
        var state = JobDetailFeature.State(job: .mock())
        state.showCalendarPicker = true
        state.calendarPickerInterviewId = interviewId1

        // Simulate the binding get logic for interviewId2's row
        let isShownForRow2 = state.showCalendarPicker && state.calendarPickerInterviewId == interviewId2
        XCTAssertFalse(isShownForRow2)
    }

    func testPickerBindingTrueWhenInterviewIdMatches() {
        let interviewId = UUID()
        var state = JobDetailFeature.State(job: .mock())
        state.showCalendarPicker = true
        state.calendarPickerInterviewId = interviewId

        let isShownForRow = state.showCalendarPicker && state.calendarPickerInterviewId == interviewId
        XCTAssertTrue(isShownForRow)
    }

    // MARK: - calendarEventsLoaded Direct Action

    func testCalendarEventsLoadedDirectlyUpdatesState() async {
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

        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.calendarEventsLoaded(events)) {
            $0.calendarEvents = events
        }
    }

    // MARK: - No requestAccess When Already Granted

    func testLinkCalendarEventWhenAlreadyGrantedDoesNotCallRequestAccess() async {
        let requestCalled = LockIsolated(false)
        let interviewId = UUID()
        let interview = InterviewRound(id: interviewId, round: 1)
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.calendarAccessGranted = true

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.calendarClient.requestAccess = {
                requestCalled.setValue(true)
                return true
            }
        }

        await store.send(.linkCalendarEvent(interviewId: interviewId)) {
            $0.showCalendarPicker = true
            $0.calendarPickerInterviewId = interviewId
        }

        XCTAssertFalse(requestCalled.value, "requestAccess should not be called when access is already granted")
    }
}
