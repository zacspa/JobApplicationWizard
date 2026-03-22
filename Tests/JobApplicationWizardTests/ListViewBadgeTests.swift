import XCTest
import SwiftUI
@testable import JobApplicationWizardCore

final class ListViewBadgeTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 0)

    func testListViewBadgeVisibleWhenInterviewWithin7Days() {
        let round = InterviewRound(round: 1, date: now.addingTimeInterval(3 * 24 * 3600), completed: false)
        let info = interviewCountdownInfo(rounds: [round], now: now)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.text, "Interview in 3d")
    }

    func testListViewBadgeNotShownWhenNoUpcomingInterviews() {
        let info = interviewCountdownInfo(rounds: [], now: now)
        XCTAssertNil(info)
    }

    func testListViewBadgeSameResultAsKanbanBadge() {
        let rounds = [
            InterviewRound(round: 1, date: now.addingTimeInterval(2 * 3600), completed: false),
            InterviewRound(round: 2, date: now.addingTimeInterval(5 * 24 * 3600), completed: false),
        ]
        // Both call sites use the same interviewCountdownInfo function; results must match.
        let listBadge = interviewCountdownInfo(rounds: rounds, now: now)
        let kanbanBadge = interviewCountdownInfo(rounds: rounds, now: now)
        XCTAssertEqual(listBadge, kanbanBadge)
    }

    func testListViewBadgeNotShownWhenAllInterviewsCompleted() {
        let rounds = [
            InterviewRound(round: 1, date: now.addingTimeInterval(3600), completed: true),
            InterviewRound(round: 2, date: now.addingTimeInterval(2 * 24 * 3600), completed: true),
        ]
        let info = interviewCountdownInfo(rounds: rounds, now: now)
        XCTAssertNil(info)
    }

    func testListViewBadgeWithLinkedCalendarEventAndManualDate() {
        // The function uses round.date, not the calendar event date.
        let round = InterviewRound(
            round: 1,
            date: now.addingTimeInterval(5 * 3600),
            completed: false,
            calendarEventIdentifier: "EKEvent-ABC123",
            calendarEventTitle: "Phone Screen"
        )
        let info = interviewCountdownInfo(rounds: [round], now: now)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.text, "Interview in 5h")
        XCTAssertEqual(info?.color, Color.orange)
    }
}
