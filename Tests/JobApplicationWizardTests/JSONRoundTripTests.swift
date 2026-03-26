import XCTest
import JobApplicationShared
@testable import JobApplicationWizardCore

/// Tests that JSON produced by one platform can be decoded by the other.
/// Since both platforms share Models.swift and use default JSONEncoder/JSONDecoder,
/// this validates the encoding stays consistent after the shared target extraction.
final class JSONRoundTripTests: XCTestCase {

    // MARK: - AppDataExport Round-Trip

    func testAppDataExportFullRoundTrip() throws {
        let job = JobApplication.mock(
            noteCards: [Note(title: "First note", body: "Content", tags: ["tag1"])],
            labels: [JobLabel(name: "Remote", colorHex: "#34C759")],
            contacts: [Contact(name: "Alice", title: "Recruiter", email: "a@co.com", linkedin: "linkedin.com/alice")],
            interviews: [InterviewRound(round: 1, type: "Phone Screen", date: Date(), interviewers: "Bob")],
            chatHistory: [ChatMessage(role: .user, content: "Help me prepare")],
            documents: [JobDocument(filename: "resume.pdf", documentType: .pdf, rawText: "Resume content", fileSize: 1024)],
            tasks: [SubTask(title: "Apply online", forStatus: .applied)]
        )

        var settings = AppSettings()
        settings.userProfile.name = "Test User"
        settings.userProfile.currentTitle = "Engineer"
        settings.autoProcessDocuments = true

        let export = AppDataExport(jobs: [job], settings: settings)

        // Encode
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)

        // Decode
        let decoded = try JSONDecoder().decode(AppDataExport.self, from: data)

        // Verify structure
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.jobs.count, 1)

        // Verify job fields
        let decodedJob = decoded.jobs[0]
        XCTAssertEqual(decodedJob.id, job.id)
        XCTAssertEqual(decodedJob.company, "Acme Corp")
        XCTAssertEqual(decodedJob.title, "Software Engineer")
        XCTAssertEqual(decodedJob.status, JobStatus.wishlist)
        XCTAssertEqual(decodedJob.salary, "$120k")
        XCTAssertEqual(decodedJob.location, "Remote")
        XCTAssertEqual(decodedJob.excitement, 3)
        XCTAssertEqual(decodedJob.isFavorite, false)

        // Verify nested collections
        XCTAssertEqual(decodedJob.noteCards.count, 1)
        XCTAssertEqual(decodedJob.noteCards[0].title, "First note")
        XCTAssertEqual(decodedJob.noteCards[0].tags, ["tag1"])

        XCTAssertEqual(decodedJob.labels.count, 1)
        XCTAssertEqual(decodedJob.labels[0].name, "Remote")

        XCTAssertEqual(decodedJob.contacts.count, 1)
        XCTAssertEqual(decodedJob.contacts[0].name, "Alice")
        XCTAssertEqual(decodedJob.contacts[0].linkedin, "linkedin.com/alice")

        XCTAssertEqual(decodedJob.interviews.count, 1)
        XCTAssertEqual(decodedJob.interviews[0].type, "Phone Screen")

        XCTAssertEqual(decodedJob.tasks.count, 1)
        XCTAssertEqual(decodedJob.tasks[0].forStatus, JobStatus.applied)

        XCTAssertEqual(decodedJob.chatHistory.count, 1)
        XCTAssertEqual(decodedJob.documents.count, 1)

        // Verify settings
        XCTAssertEqual(decoded.settings.userProfile.name, "Test User")
        XCTAssertEqual(decoded.settings.autoProcessDocuments, true)
    }

    // MARK: - Date Encoding Consistency

    func testDateEncodingUsesAppleReferenceDate() throws {
        let job = JobApplication.mock(dateAdded: Date(timeIntervalSinceReferenceDate: 1000))
        let data = try JSONEncoder().encode(job)
        let json = String(data: data, encoding: .utf8)!

        // Default JSONEncoder uses .deferredToDate which encodes as
        // TimeInterval since Apple reference date (2001-01-01).
        // The value 1000 should appear directly in the JSON.
        XCTAssertTrue(json.contains("1000"), "Date should encode as Apple reference seconds, got: \(json)")
    }

    // MARK: - Enum Raw Values Match Desktop

    func testJobStatusRawValues() {
        // These must match exactly; the desktop app encodes/decodes with these strings
        XCTAssertEqual(JobStatus.wishlist.rawValue, "Wishlist")
        XCTAssertEqual(JobStatus.applied.rawValue, "Applied")
        XCTAssertEqual(JobStatus.phoneScreen.rawValue, "Phone Screen")
        XCTAssertEqual(JobStatus.interview.rawValue, "Interview")
        XCTAssertEqual(JobStatus.offer.rawValue, "Offer")
        XCTAssertEqual(JobStatus.rejected.rawValue, "Rejected")
        XCTAssertEqual(JobStatus.withdrawn.rawValue, "Withdrawn")
    }

    func testATSProviderRawValues() {
        XCTAssertEqual(ATSProvider.greenhouse.rawValue, "greenhouse")
        XCTAssertEqual(ATSProvider.lever.rawValue, "lever")
        XCTAssertEqual(ATSProvider.unknown.rawValue, "unknown")
    }

    func testDocumentTypeRawValues() {
        XCTAssertEqual(DocumentType.pdf.rawValue, "pdf")
        XCTAssertEqual(DocumentType.docx.rawValue, "docx")
        XCTAssertEqual(DocumentType.rtf.rawValue, "rtf")
        XCTAssertEqual(DocumentType.txt.rawValue, "txt")
        XCTAssertEqual(DocumentType.md.rawValue, "md")
    }

    func testViewModeRawValues() {
        XCTAssertEqual(ViewMode.kanban.rawValue, "Kanban")
        XCTAssertEqual(ViewMode.list.rawValue, "List")
    }

    func testAIProviderRawValues() {
        XCTAssertEqual(AIProvider.claudeAPI.rawValue, "Claude API")
        XCTAssertEqual(AIProvider.acpAgent.rawValue, "ACP Agent")
    }

    func testAgentActionModeRawValues() {
        XCTAssertEqual(AgentActionMode.applyImmediately.rawValue, "Apply Immediately")
        XCTAssertEqual(AgentActionMode.requireApproval.rawValue, "Require Approval")
    }

    // MARK: - Legacy Migration

    func testLegacyNotesFieldMigratesToNoteCards() throws {
        // Simulate a JSON export from an older version with "notes" string instead of "noteCards"
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "company": "OldCo",
            "title": "Dev",
            "url": "",
            "status": "Wishlist",
            "dateAdded": 0,
            "salary": "",
            "location": "",
            "jobDescription": "",
            "resumeUsed": "",
            "coverLetter": "",
            "excitement": 3,
            "isFavorite": false,
            "hasPDF": false,
            "notes": "This is a legacy note",
            "labels": [],
            "contacts": [],
            "interviews": [],
            "tasks": []
        }
        """
        let data = json.data(using: .utf8)!
        let job = try JSONDecoder().decode(JobApplication.self, from: data)

        // Legacy "notes" should be migrated into noteCards
        XCTAssertEqual(job.noteCards.count, 1)
        XCTAssertEqual(job.noteCards.first?.body, "This is a legacy note")
    }

    // MARK: - Optional Fields

    func testOptionalFieldsDecodeAsNil() throws {
        // Minimal JSON with only required-ish fields
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "company": "MinCo",
            "title": "Dev",
            "status": "Wishlist"
        }
        """
        let data = json.data(using: .utf8)!
        let job = try JSONDecoder().decode(JobApplication.self, from: data)

        XCTAssertEqual(job.company, "MinCo")
        XCTAssertNil(job.dateApplied)
        XCTAssertNil(job.pdfPath)
        XCTAssertEqual(job.noteCards, [])
        XCTAssertEqual(job.labels, [])
    }
}
