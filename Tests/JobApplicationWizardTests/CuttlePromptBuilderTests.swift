import XCTest
@testable import JobApplicationWizardCore

final class CuttlePromptBuilderTests: XCTestCase {

    func testPromptIncludesCalendarEventTitleForLinkedRound() {
        let job = JobApplication.mock(
            company: "Acme", title: "Engineer", status: .interview,
            interviews: [InterviewRound(
                round: 1, type: "Technical",
                calendarEventIdentifier: "EKEvent-ABC",
                calendarEventTitle: "ACME Technical Screen"
            )]
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )
        XCTAssertTrue(prompt.contains("ACME Technical Screen"))
    }

    func testPromptExcludesCalendarSectionForUnlinkedRound() {
        let job = JobApplication.mock(
            company: "Acme", title: "Engineer", status: .interview,
            interviews: [InterviewRound(round: 1, type: "Technical")]
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )
        XCTAssertFalse(prompt.contains("Calendar:"))
    }

    func testPromptIncludesMultipleLinkedRounds() {
        let job = JobApplication.mock(
            company: "Corp", title: "Dev", status: .interview,
            interviews: [
                InterviewRound(
                    round: 1, type: "Phone",
                    calendarEventIdentifier: "EKEvent-1",
                    calendarEventTitle: "Corp Phone Screen"
                ),
                InterviewRound(
                    round: 2, type: "Technical",
                    calendarEventIdentifier: "EKEvent-2",
                    calendarEventTitle: "Corp Tech Interview"
                )
            ]
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )
        XCTAssertTrue(prompt.contains("Corp Phone Screen"))
        XCTAssertTrue(prompt.contains("Corp Tech Interview"))
    }

    func testPromptUsesCalendarFormatCorrectly() {
        let job = JobApplication.mock(
            company: "Acme", title: "Engineer", status: .interview,
            interviews: [InterviewRound(
                round: 1, type: "Technical",
                calendarEventIdentifier: "EKEvent-XYZ",
                calendarEventTitle: "My Interview"
            )]
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )
        XCTAssertTrue(prompt.contains("Calendar: 'My Interview'"))
    }

    func testNilTitleFallbackInPrompt() {
        let job = JobApplication.mock(
            company: "Acme", title: "Engineer", status: .interview,
            interviews: [InterviewRound(
                round: 1, type: "Hiring Manager",
                calendarEventIdentifier: "EKEvent-DEF",
                calendarEventTitle: nil
            )]
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )
        XCTAssertTrue(prompt.contains("Calendar: 'Linked event'"))
    }
}
