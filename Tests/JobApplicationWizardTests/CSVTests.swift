import XCTest
@testable import JobApplicationWizardCore

final class CSVTests: XCTestCase {

    // Use the live persistence client's exportCSV/importCSV closures directly —
    // they are pure functions (no disk I/O).
    private let export: ([JobApplication]) -> String = PersistenceClient.liveValue.exportCSV
    private let importCSV: (String) -> [JobApplication] = PersistenceClient.liveValue.importCSV

    // MARK: - Round-Trips

    func testSingleJobRoundTrip() {
        let job = JobApplication.mock()
        let csv = export([job])
        let imported = importCSV(csv)
        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported.first?.id, job.id)
        XCTAssertEqual(imported.first?.company, "Acme Corp")
        XCTAssertEqual(imported.first?.title, "Software Engineer")
        XCTAssertEqual(imported.first?.status, .wishlist)
        XCTAssertEqual(imported.first?.salary, "$120k")
    }

    func testMultipleJobsRoundTrip() {
        let job1 = JobApplication.mock(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            company: "Alpha",
            dateAdded: Date(timeIntervalSinceReferenceDate: 100)
        )
        let job2 = JobApplication.mock(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            company: "Beta",
            dateAdded: Date(timeIntervalSinceReferenceDate: 200)
        )
        let csv = export([job1, job2])
        let imported = importCSV(csv)
        XCTAssertEqual(imported.count, 2)
        let companies = Set(imported.map(\.company))
        XCTAssertTrue(companies.contains("Alpha"))
        XCTAssertTrue(companies.contains("Beta"))
    }

    func testRoundTripWithLabels() {
        let job = JobApplication.mock(
            labels: [JobLabel(name: "Remote", colorHex: "#34C759")]
        )
        let csv = export([job])
        let imported = importCSV(csv)
        XCTAssertEqual(imported.first?.labels.count, 1)
        XCTAssertEqual(imported.first?.labels.first?.name, "Remote")
    }

    func testRoundTripWithContacts() {
        let contact = Contact(name: "Alice", title: "Recruiter", email: "a@b.com")
        let job = JobApplication.mock(contacts: [contact])
        let csv = export([job])
        let imported = importCSV(csv)
        XCTAssertEqual(imported.first?.contacts.count, 1)
        XCTAssertEqual(imported.first?.contacts.first?.name, "Alice")
    }

    func testRoundTripWithInterviews() {
        let interview = InterviewRound(round: 1, type: "Phone", interviewers: "Bob")
        let job = JobApplication.mock(interviews: [interview])
        let csv = export([job])
        let imported = importCSV(csv)
        XCTAssertEqual(imported.first?.interviews.count, 1)
        XCTAssertEqual(imported.first?.interviews.first?.type, "Phone")
    }

    func testRoundTripWithNoteCards() {
        let note = Note(title: "First", body: "Some content")
        let job = JobApplication.mock(noteCards: [note])
        let csv = export([job])
        let imported = importCSV(csv)
        XCTAssertEqual(imported.first?.noteCards.count, 1)
        XCTAssertEqual(imported.first?.noteCards.first?.title, "First")
    }

    // MARK: - Edge Cases

    func testEmbeddedCommas() {
        let job = JobApplication.mock(company: "Acme, Inc.", salary: "$100,000")
        let csv = export([job])
        let imported = importCSV(csv)
        XCTAssertEqual(imported.first?.company, "Acme, Inc.")
        XCTAssertEqual(imported.first?.salary, "$100,000")
    }

    func testEmbeddedNewlines() {
        let job = JobApplication.mock(jobDescription: "Line one\nLine two\nLine three")
        let csv = export([job])
        let imported = importCSV(csv)
        XCTAssertEqual(imported.first?.jobDescription, "Line one\nLine two\nLine three")
    }

    func testEscapedQuotes() {
        let job = JobApplication.mock(company: "Say \"Hello\" Corp")
        let csv = export([job])
        let imported = importCSV(csv)
        XCTAssertEqual(imported.first?.company, "Say \"Hello\" Corp")
    }

    // MARK: - Empty / Header-Only

    func testEmptyInputReturnsEmptyArray() {
        XCTAssertEqual(importCSV("").count, 0)
    }

    func testHeaderOnlyReturnsEmptyArray() {
        let csv = "ID,Company,Title,URL,Status,DateAdded,DateApplied,Salary,Location,Excitement,IsFavorite,Labels,JobDescription,NoteCards,ResumeUsed,CoverLetter,Contacts,Interviews,HasPDF,PDFPath"
        XCTAssertEqual(importCSV(csv).count, 0)
    }

    // MARK: - Invalid Rows

    func testRowsWithBothCompanyAndTitleEmptySkipped() {
        // Build a CSV with a valid header and one row that has empty company and title
        let header = "ID,Company,Title,URL,Status"
        let row = "\"00000000-0000-0000-0000-000000000099\",\"\",\"\",\"\",\"Wishlist\""
        let csv = header + "\n" + row
        let imported = importCSV(csv)
        XCTAssertEqual(imported.count, 0)
    }

    // MARK: - Sort Order

    func testExportSortsByDateAddedDescending() {
        let older = JobApplication.mock(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            company: "Older",
            dateAdded: Date(timeIntervalSinceReferenceDate: 100)
        )
        let newer = JobApplication.mock(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            company: "Newer",
            dateAdded: Date(timeIntervalSinceReferenceDate: 200)
        )
        let csv = export([older, newer])
        let lines = csv.components(separatedBy: "\n")
        // First data line (index 1) should be the newer job
        XCTAssertTrue(lines[1].contains("Newer"))
        XCTAssertTrue(lines[2].contains("Older"))
    }
}
