import XCTest
import SwiftUI
@testable import JobApplicationWizardCore

final class ModelTests: XCTestCase {

    // MARK: - JobApplication Codable Round-Trip

    func testJobApplicationCodableRoundTrip() throws {
        let job = JobApplication.mock(
            noteCards: [Note(title: "First", body: "Body text")],
            labels: [JobLabel(name: "Remote", colorHex: "#34C759")],
            contacts: [Contact(name: "Alice", title: "Recruiter")],
            interviews: [InterviewRound(round: 1, type: "Phone")]
        )
        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(JobApplication.self, from: data)
        XCTAssertEqual(decoded.id, job.id)
        XCTAssertEqual(decoded.company, job.company)
        XCTAssertEqual(decoded.title, job.title)
        XCTAssertEqual(decoded.status, job.status)
        XCTAssertEqual(decoded.labels.count, 1)
        XCTAssertEqual(decoded.contacts.count, 1)
        XCTAssertEqual(decoded.interviews.count, 1)
        XCTAssertEqual(decoded.noteCards.count, 1)
        XCTAssertEqual(decoded.excitement, 3)
    }

    func testAppSettingsCodableRoundTrip() throws {
        var settings = AppSettings()
        settings.userProfile.name = "Test User"
        settings.defaultViewMode = .list
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.userProfile.name, "Test User")
        XCTAssertEqual(decoded.defaultViewMode, .list)
    }

    // MARK: - Legacy Migration

    func testLegacyNotesStringMigratesToNoteCards() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","company":"Test","notes":"Old notes text"}
        """
        let job = try JSONDecoder().decode(JobApplication.self, from: Data(json.utf8))
        XCTAssertEqual(job.noteCards.count, 1)
        XCTAssertEqual(job.noteCards.first?.title, "Notes")
        XCTAssertEqual(job.noteCards.first?.body, "Old notes text")
    }

    func testEmptyLegacyNotesDoesNotCreateNoteCard() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","company":"Test","notes":""}
        """
        let job = try JSONDecoder().decode(JobApplication.self, from: Data(json.utf8))
        XCTAssertEqual(job.noteCards.count, 0)
    }

    func testNoteCardsPreferredOverLegacyNotes() throws {
        let json = """
        {"company":"Test","noteCards":[{"id":"00000000-0000-0000-0000-000000000002","title":"Card","subtitle":"","body":"New","tags":[],"createdAt":0,"updatedAt":0}],"notes":"Old"}
        """
        let job = try JSONDecoder().decode(JobApplication.self, from: Data(json.utf8))
        XCTAssertEqual(job.noteCards.count, 1)
        XCTAssertEqual(job.noteCards.first?.body, "New")
    }

    // MARK: - AppSettings Tolerates Missing Keys

    func testAppSettingsToleratesUnknownTopLevelKeys() throws {
        // AppSettings uses explicit CodingKeys, so unknown keys at the top level are silently ignored.
        // This verifies the profile-loss bug fix: unknown keys don't crash decoding.
        let json = """
        {"unknownKey":"something","defaultViewMode":"Kanban"}
        """
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.userProfile.name, "")
        XCTAssertEqual(settings.defaultViewMode, .kanban)
    }

    func testAppSettingsDefaultsOnEmptyJSON() throws {
        let json = "{}"
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.userProfile.name, "")
        XCTAssertEqual(settings.defaultViewMode, .kanban)
    }

    // MARK: - JobApplication Defaults on Empty JSON

    func testJobApplicationDefaultsOnEmptyJSON() throws {
        let json = "{}"
        let job = try JSONDecoder().decode(JobApplication.self, from: Data(json.utf8))
        XCTAssertEqual(job.company, "")
        XCTAssertEqual(job.title, "")
        XCTAssertEqual(job.status, .wishlist)
        XCTAssertEqual(job.excitement, 3)
        XCTAssertFalse(job.isFavorite)
        XCTAssertEqual(job.noteCards, [])
    }

    // MARK: - Computed Properties

    func testDisplayTitleFallback() {
        var job = JobApplication()
        XCTAssertEqual(job.displayTitle, "Untitled Position")
        job.title = "Engineer"
        XCTAssertEqual(job.displayTitle, "Engineer")
    }

    func testDisplayCompanyFallback() {
        var job = JobApplication()
        XCTAssertEqual(job.displayCompany, "Unknown Company")
        job.company = "Acme"
        XCTAssertEqual(job.displayCompany, "Acme")
    }

    // MARK: - Color Hex

    func testColorInitFromHexWithHash() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
    }

    func testColorInitFromHexWithoutHash() {
        let color = Color(hex: "00FF00")
        XCTAssertNotNil(color)
    }

    func testColorInitFromInvalidHex() {
        XCTAssertNil(Color(hex: "ZZZ"))
        XCTAssertNil(Color(hex: "#12"))
        XCTAssertNil(Color(hex: ""))
    }

    // MARK: - String.wordCount

    func testWordCountEmpty() {
        XCTAssertEqual("".wordCount, 0)
    }

    func testWordCountSingle() {
        XCTAssertEqual("hello".wordCount, 1)
    }

    func testWordCountMulti() {
        XCTAssertEqual("hello world foo".wordCount, 3)
    }

    func testWordCountWhitespaceHeavy() {
        XCTAssertEqual("  hello   world  ".wordCount, 2)
    }

    // MARK: - InterviewRound Calendar Fields

    func testInterviewRoundDecodesWithoutCalendarFields() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","round":1,"type":"Phone","interviewers":"","notes":"","completed":false}
        """
        let round = try JSONDecoder().decode(InterviewRound.self, from: Data(json.utf8))
        XCTAssertNil(round.calendarEventIdentifier)
        XCTAssertNil(round.calendarEventTitle)
    }

    func testInterviewRoundDecodesWithCalendarFields() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","round":1,"type":"Phone","interviewers":"","notes":"","completed":false,"calendarEventIdentifier":"ABC-123","calendarEventTitle":"Phone Screen"}
        """
        let round = try JSONDecoder().decode(InterviewRound.self, from: Data(json.utf8))
        XCTAssertEqual(round.calendarEventIdentifier, "ABC-123")
        XCTAssertEqual(round.calendarEventTitle, "Phone Screen")
    }

    func testInterviewRoundCodableRoundTripWithCalendarFields() throws {
        let original = InterviewRound(round: 2, type: "Onsite", calendarEventIdentifier: "EV-456", calendarEventTitle: "Onsite Interview")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InterviewRound.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.calendarEventIdentifier, "EV-456")
        XCTAssertEqual(decoded.calendarEventTitle, "Onsite Interview")
    }

    func testInterviewRoundEqualityDiffersOnCalendarEventIdentifier() {
        let base = InterviewRound(round: 1)
        var other = base
        other.calendarEventIdentifier = "SOME-ID"
        XCTAssertNotEqual(base, other)
    }

    // MARK: - AITokenUsage

    func testAITokenUsageEstimatedCost() {
        let usage = AITokenUsage(inputTokens: 1_000_000, outputTokens: 1_000_000)
        // $3/MTok in + $15/MTok out = $18
        XCTAssertEqual(usage.estimatedCost, 18.0, accuracy: 0.001)
    }

    func testAITokenUsageZero() {
        XCTAssertEqual(AITokenUsage.zero.inputTokens, 0)
        XCTAssertEqual(AITokenUsage.zero.outputTokens, 0)
        XCTAssertEqual(AITokenUsage.zero.estimatedCost, 0.0)
    }

    func testAITokenUsageTotalTokens() {
        let usage = AITokenUsage(inputTokens: 100, outputTokens: 200)
        XCTAssertEqual(usage.totalTokens, 300)
    }
}
