import XCTest
import SwiftUI
@testable import JobApplicationWizardCore

final class KanbanBadgeTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 0)

    // MARK: - Text Formatting

    func testBadge8DaysAway() {
        let interviewDate = now.addingTimeInterval(8 * 24 * 3600)
        let round = InterviewRound(round: 1, date: interviewDate, completed: false)
        let info = interviewCountdownInfo(rounds: [round], now: now)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        XCTAssertEqual(info?.text, "Interview \(formatter.string(from: interviewDate))")
        XCTAssertEqual(info?.isItalic, false)
    }

    func testBadge3DaysAway() {
        let round = InterviewRound(round: 1, date: now.addingTimeInterval(3 * 24 * 3600), completed: false)
        let info = interviewCountdownInfo(rounds: [round], now: now)
        XCTAssertEqual(info?.text, "Interview in 3d")
    }

    func testBadge1Day5HoursAway() {
        let round = InterviewRound(round: 1, date: now.addingTimeInterval(1 * 24 * 3600 + 5 * 3600), completed: false)
        let info = interviewCountdownInfo(rounds: [round], now: now)
        XCTAssertEqual(info?.text, "Interview in 1d 5h")
    }

    func testBadge3HoursAway() {
        let round = InterviewRound(round: 1, date: now.addingTimeInterval(3 * 3600), completed: false)
        let info = interviewCountdownInfo(rounds: [round], now: now)
        XCTAssertEqual(info?.text, "Interview in 3h")
        XCTAssertEqual(info?.color, Color.orange)
        XCTAssertEqual(info?.isItalic, false)
    }

    func testBadge45MinutesAway() {
        let round = InterviewRound(round: 1, date: now.addingTimeInterval(45 * 60), completed: false)
        let info = interviewCountdownInfo(rounds: [round], now: now)
        XCTAssertEqual(info?.text, "Interview in 45m")
        XCTAssertEqual(info?.color, Color.red)
        XCTAssertEqual(info?.isItalic, false)
    }

    func testBadge2HoursAgo() {
        let round = InterviewRound(round: 1, date: now.addingTimeInterval(-2 * 3600), completed: false)
        let info = interviewCountdownInfo(rounds: [round], now: now)
        XCTAssertEqual(info?.text, "Interview was 2h ago")
        XCTAssertEqual(info?.color, Color.gray)
        XCTAssertEqual(info?.isItalic, true)
    }

    // MARK: - No Badge Cases

    func testNoBadgeWhenAllCompleted() {
        let round = InterviewRound(round: 1, date: now.addingTimeInterval(3600), completed: true)
        let info = interviewCountdownInfo(rounds: [round], now: now)
        XCTAssertNil(info)
    }

    func testNoBadgeWhenNoRounds() {
        let info = interviewCountdownInfo(rounds: [], now: now)
        XCTAssertNil(info)
    }

    // MARK: - Selection Logic

    func testNearestFutureSelectedWhenMultipleRoundsExist() {
        let closer = InterviewRound(round: 1, date: now.addingTimeInterval(3 * 3600), completed: false)
        let farther = InterviewRound(round: 2, date: now.addingTimeInterval(3 * 24 * 3600), completed: false)
        let info = interviewCountdownInfo(rounds: [farther, closer], now: now)
        XCTAssertEqual(info?.text, "Interview in 3h")
    }

    func testCompletedInterviewsExcludedWhenSelectingNearest() {
        let completed = InterviewRound(round: 1, date: now.addingTimeInterval(1 * 3600), completed: true)
        let incomplete = InterviewRound(round: 2, date: now.addingTimeInterval(5 * 3600), completed: false)
        let info = interviewCountdownInfo(rounds: [completed, incomplete], now: now)
        XCTAssertEqual(info?.text, "Interview in 5h")
    }

    // MARK: - Edge Cases

    func testEdgeCaseExactly24HoursBoundary() {
        let round = InterviewRound(round: 1, date: now.addingTimeInterval(24 * 3600), completed: false)
        let info = interviewCountdownInfo(rounds: [round], now: now)
        // Exactly 24 hours: 1 day, 0 remaining hours → "Interview in 1d"
        XCTAssertEqual(info?.text, "Interview in 1d")
        XCTAssertEqual(info?.color, Color.secondary)
    }

    func testEdgeCaseExactly2HoursBoundary() {
        let round = InterviewRound(round: 1, date: now.addingTimeInterval(2 * 3600), completed: false)
        let info = interviewCountdownInfo(rounds: [round], now: now)
        // Exactly 2 hours: orange (not red)
        XCTAssertEqual(info?.text, "Interview in 2h")
        XCTAssertEqual(info?.color, Color.orange)
    }
}
