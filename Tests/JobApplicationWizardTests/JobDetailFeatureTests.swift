import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class JobDetailFeatureTests: XCTestCase {

    // MARK: - State Init

    func testStateInitMapsAllFieldsFromJob() {
        let job = JobApplication.mock(
            company: "Acme",
            title: "Engineer",
            url: "https://acme.com",
            salary: "$100k",
            location: "Remote",
            jobDescription: "Do things",
            noteCards: [Note(title: "N1")],
            labels: [JobLabel(name: "Remote", colorHex: "#34C759")],
            contacts: [Contact(name: "Alice")],
            interviews: [InterviewRound(round: 1)]
        )
        let state = JobDetailFeature.State(job: job, apiKey: "key", userProfile: UserProfile())
        XCTAssertEqual(state.company, "Acme")
        XCTAssertEqual(state.title, "Engineer")
        XCTAssertEqual(state.location, "Remote")
        XCTAssertEqual(state.salary, "$100k")
        XCTAssertEqual(state.url, "https://acme.com")
        XCTAssertEqual(state.jobDescription, "Do things")
        XCTAssertEqual(state.noteCards.count, 1)
        XCTAssertEqual(state.labels.count, 1)
        XCTAssertEqual(state.contacts.count, 1)
        XCTAssertEqual(state.interviews.count, 1)
        XCTAssertEqual(state.apiKey, "key")
    }

    // MARK: - syncJobFromFields

    func testSyncJobFromFieldsWritesBack() {
        let job = JobApplication.mock()
        var state = JobDetailFeature.State(job: job)
        state.company = "Changed"
        state.title = "New Title"
        state.syncJobFromFields()
        XCTAssertEqual(state.job.company, "Changed")
        XCTAssertEqual(state.job.title, "New Title")
    }

    // MARK: - Tab Selection

    func testSelectTab() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.selectTab(.notes)) {
            $0.selectedTab = .notes
        }
    }

    // MARK: - Excitement

    func testSetExcitement() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.setExcitement(5)) {
            $0.job.excitement = 5
        }
        await store.receive(\.delegate.jobUpdated)
    }

    // MARK: - Favorite

    func testToggleFavorite() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.toggleFavorite) {
            $0.job.isFavorite = true
        }
        await store.receive(\.delegate.jobUpdated)
    }

    // MARK: - moveJob

    func testMoveJob() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.moveJob(.interview)) {
            $0.job.status = .interview
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testMoveJobToAppliedSetsDateApplied() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.moveJob(.applied))

        XCTAssertEqual(store.state.job.status, .applied)
        XCTAssertNotNil(store.state.job.dateApplied)
    }

    // MARK: - markApplied

    func testMarkApplied() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.markApplied)

        XCTAssertEqual(store.state.job.status, .applied)
        XCTAssertNotNil(store.state.job.dateApplied)
    }

    // MARK: - Delete Flow

    func testDeleteTappedShowsConfirm() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.deleteTapped) {
            $0.showDeleteConfirm = true
        }
    }

    func testDeleteConfirmedDelegates() async {
        var state = JobDetailFeature.State(job: .mock())
        state.showDeleteConfirm = true

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirm = false
        }
        await store.receive(\.delegate.jobDeleted)
    }

    func testDeleteCancelled() async {
        var state = JobDetailFeature.State(job: .mock())
        state.showDeleteConfirm = true

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.deleteCancelled) {
            $0.showDeleteConfirm = false
        }
    }

    // MARK: - Notes CRUD

    func testAddNote() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.addNote)

        XCTAssertEqual(store.state.noteCards.count, 1)
        XCTAssertEqual(store.state.job.noteCards.count, 1)
    }

    func testDeleteNote() async {
        let note = Note(id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!, title: "Test")
        let job = JobApplication.mock(noteCards: [note])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.deleteNote(note.id)) {
            $0.noteCards = []
            $0.job.noteCards = []
        }
        await store.receive(\.delegate.jobUpdated)
    }

    // MARK: - Contact CRUD

    func testAddContact() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.addContact)

        XCTAssertEqual(store.state.contacts.count, 1)
        XCTAssertEqual(store.state.job.contacts.count, 1)
    }

    func testDeleteContact() async {
        let contact = Contact(name: "Alice")
        let job = JobApplication.mock(contacts: [contact])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.deleteContact(IndexSet(integer: 0))) {
            $0.contacts = []
            $0.job.contacts = []
        }
        await store.receive(\.delegate.jobUpdated)
    }

    // MARK: - Interview CRUD

    func testAddInterview() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.addInterview)

        XCTAssertEqual(store.state.interviews.count, 1)
        XCTAssertEqual(store.state.interviews.first?.round, 1)
        XCTAssertEqual(store.state.job.interviews.count, 1)
    }

    func testDeleteInterview() async {
        let interview = InterviewRound(round: 1, type: "Phone")
        let job = JobApplication.mock(interviews: [interview])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.deleteInterview(IndexSet(integer: 0))) {
            $0.interviews = []
            $0.job.interviews = []
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testDeleteMiddleInterview() async {
        let interviews = [
            InterviewRound(round: 1, type: "Phone"),
            InterviewRound(round: 2, type: "Technical"),
            InterviewRound(round: 3, type: "Onsite"),
        ]
        let job = JobApplication.mock(interviews: interviews)

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.deleteInterview(IndexSet(integer: 1))) {
            $0.interviews = [interviews[0], interviews[2]]
            $0.job.interviews = [interviews[0], interviews[2]]
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testDeleteLastInterviewFromMultiples() async {
        let interviews = [
            InterviewRound(round: 1, type: "Phone"),
            InterviewRound(round: 2, type: "Technical"),
        ]
        let job = JobApplication.mock(interviews: interviews)

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.deleteInterview(IndexSet(integer: 1))) {
            $0.interviews = [interviews[0]]
            $0.job.interviews = [interviews[0]]
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testInterviewDatesPreservedInState() async {
        let date1 = Date(timeIntervalSinceReferenceDate: 1000)
        let date2 = Date(timeIntervalSinceReferenceDate: 2000)
        let interviews = [
            InterviewRound(round: 1, type: "Phone", date: date1, completed: true),
            InterviewRound(round: 2, type: "Technical", date: date2),
        ]
        let job = JobApplication.mock(interviews: interviews)

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        XCTAssertEqual(store.state.interviews.count, 2)
        XCTAssertEqual(store.state.interviews[0].date, date1)
        XCTAssertEqual(store.state.interviews[0].completed, true)
        XCTAssertEqual(store.state.interviews[1].date, date2)
        XCTAssertEqual(store.state.interviews[1].completed, false)
        XCTAssertEqual(store.state.job.interviews.count, 2)
    }

    func testAddMultipleInterviewsIncrementsRound() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.addInterview)
        await store.send(.addInterview)
        await store.send(.addInterview)

        XCTAssertEqual(store.state.interviews.count, 3)
        XCTAssertEqual(store.state.interviews[0].round, 1)
        XCTAssertEqual(store.state.interviews[1].round, 2)
        XCTAssertEqual(store.state.interviews[2].round, 3)
    }

    // MARK: - PDF

    func testSavePDFSuccess() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        } withDependencies: {
            $0.pdfClient.generateAndSavePDF = { _ in "/path/to/pdf" }
        }

        await store.send(.savePDFTapped) {
            $0.isGeneratingPDF = true
            $0.pdfError = nil
        }

        await store.receive(\.pdfSaved.success) {
            $0.isGeneratingPDF = false
            $0.job.hasPDF = true
            $0.job.pdfPath = "/path/to/pdf"
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testSavePDFFailure() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        } withDependencies: {
            $0.pdfClient.generateAndSavePDF = { _ in
                throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "PDF failed"])
            }
        }

        await store.send(.savePDFTapped) {
            $0.isGeneratingPDF = true
            $0.pdfError = nil
        }

        await store.receive(\.pdfSaved.failure) {
            $0.isGeneratingPDF = false
            $0.pdfError = "PDF failed"
        }
    }

    func testViewPDFWithPath() async {
        var job = JobApplication.mock()
        job.pdfPath = "/some/path.pdf"
        let openedPath = LockIsolated<String?>(nil)

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        } withDependencies: {
            $0.pdfClient.openPDF = { path in
                openedPath.setValue(path)
            }
        }

        await store.send(.viewPDFTapped)
        XCTAssertEqual(openedPath.value, "/some/path.pdf")
    }

    func testViewPDFWithoutPathDoesNothing() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.viewPDFTapped)
        // No effect, no crash
    }

    // MARK: - Tab Enum Properties

    func testTabLabels() {
        XCTAssertEqual(JobDetailFeature.State.Tab.overview.label, "Overview")
        XCTAssertEqual(JobDetailFeature.State.Tab.description.label, "JD")
        XCTAssertEqual(JobDetailFeature.State.Tab.notes.label, "Notes")
        XCTAssertEqual(JobDetailFeature.State.Tab.contacts.label, "Contacts")
        XCTAssertEqual(JobDetailFeature.State.Tab.interviews.label, "Interviews")
    }

    func testTabIcons() {
        XCTAssertEqual(JobDetailFeature.State.Tab.overview.icon, "info.circle")
        XCTAssertEqual(JobDetailFeature.State.Tab.description.icon, "doc.text")
        XCTAssertEqual(JobDetailFeature.State.Tab.notes.icon, "note.text")
        XCTAssertEqual(JobDetailFeature.State.Tab.contacts.icon, "person.2")
        XCTAssertEqual(JobDetailFeature.State.Tab.interviews.icon, "calendar.badge.clock")
    }

    // MARK: - CuttlePromptBuilder (migrated from JobDetailFeature.buildSystemPrompt)

    func testBuildJobPromptIncludesJobContext() {
        let job = JobApplication.mock(
            company: "TestCo",
            title: "Senior Dev",
            jobDescription: "Build things"
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )

        XCTAssertTrue(prompt.contains("Senior Dev"))
        XCTAssertTrue(prompt.contains("TestCo"))
        XCTAssertTrue(prompt.contains("Build things"))
        XCTAssertTrue(prompt.contains("expert career coach"))
    }

    func testBuildJobPromptIncludesUserProfile() {
        let job = JobApplication.mock()
        var profile = UserProfile()
        profile.name = "Alice"
        profile.skills = ["Swift", "Python"]
        profile.resume = "10 years experience"

        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: profile, chatHistory: []
        )

        XCTAssertTrue(prompt.contains("Alice"))
        XCTAssertTrue(prompt.contains("Swift, Python"))
        XCTAssertTrue(prompt.contains("10 years experience"))
    }

    func testBuildJobPromptOmitsEmptyProfile() {
        let job = JobApplication.mock()
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )

        XCTAssertFalse(prompt.contains("About the candidate"))
    }

    func testBuildJobPromptIncludesContacts() {
        let job = JobApplication.mock(
            contacts: [Contact(name: "Bob", title: "Recruiter", notes: "Met at conference")]
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )

        XCTAssertTrue(prompt.contains("Bob"))
        XCTAssertTrue(prompt.contains("Recruiter"))
        XCTAssertTrue(prompt.contains("Met at conference"))
    }

    func testBuildJobPromptIncludesInterviews() {
        let job = JobApplication.mock(
            interviews: [InterviewRound(round: 1, type: "Technical", interviewers: "Jane")]
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )

        XCTAssertTrue(prompt.contains("Round 1"))
        XCTAssertTrue(prompt.contains("Technical"))
        XCTAssertTrue(prompt.contains("Jane"))
    }

    func testBuildJobPromptIncludesNotes() {
        let job = JobApplication.mock(
            noteCards: [Note(title: "Salary Research", body: "Glassdoor says $150k")]
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )

        XCTAssertTrue(prompt.contains("Salary Research"))
        XCTAssertTrue(prompt.contains("Glassdoor says $150k"))
    }

    func testBuildJobPromptIncludesRecentActivity() {
        let job = JobApplication.mock()
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )

        XCTAssertTrue(prompt.contains("Recent Activity"))
        XCTAssertTrue(prompt.contains("Added:"))
    }

    func testBuildJobPromptIncludesLabelsAndSalary() {
        let job = JobApplication.mock(
            salary: "$120k-150k",
            labels: [JobLabel(name: "Remote", colorHex: "#34C759")]
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: []
        )

        XCTAssertTrue(prompt.contains("$120k-150k"))
        XCTAssertTrue(prompt.contains("Remote"))
    }

    func testBuildPromptIncludesChatHistoryTail() {
        let job = JobApplication.mock()
        let history = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there!"),
        ]
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(job.id), jobs: [job], profile: UserProfile(), chatHistory: history
        )

        XCTAssertTrue(prompt.contains("Previous conversation"))
        XCTAssertTrue(prompt.contains("User: Hello"))
        XCTAssertTrue(prompt.contains("Assistant: Hi there!"))
    }

    func testBuildGlobalPromptIncludesAllJobs() {
        let jobs = [
            JobApplication.mock(company: "Acme", title: "Engineer"),
            JobApplication.mock(company: "BigCo", title: "Manager"),
        ]
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .global, jobs: jobs, profile: UserProfile(), chatHistory: []
        )

        XCTAssertTrue(prompt.contains("Acme"))
        XCTAssertTrue(prompt.contains("BigCo"))
        XCTAssertTrue(prompt.contains("full job search dashboard"))
    }

    func testBuildStatusPromptScopesToStatus() {
        let jobs = [
            JobApplication.mock(company: "Acme", title: "Engineer", status: .interview),
            JobApplication.mock(company: "BigCo", title: "Manager", status: .wishlist),
        ]
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .status(.interview), jobs: jobs, profile: UserProfile(), chatHistory: []
        )

        XCTAssertTrue(prompt.contains("Acme"))
        XCTAssertTrue(prompt.contains("Interview jobs"))
    }

    // MARK: - Calendar Picker State and Actions

    func testLinkCalendarEventSetsPickerState() async {
        let interviewId = UUID()
        let interview = InterviewRound(id: interviewId, round: 1)
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.calendarAccessGranted = true  // already granted, no effect

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.linkCalendarEvent(interviewId: interviewId)) {
            $0.showCalendarPicker = true
            $0.calendarPickerInterviewId = interviewId
        }
    }

    func testLinkCalendarEventWhenAccessNilTriggersRequestAccess() async {
        let interviewId = UUID()
        let interview = InterviewRound(id: interviewId, round: 1)
        let job = JobApplication.mock(interviews: [interview])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        } withDependencies: {
            $0.calendarClient.requestAccess = { true }
            $0.calendarClient.fetchEvents = { _, _ in [] }
        }

        await store.send(.linkCalendarEvent(interviewId: interviewId)) {
            $0.showCalendarPicker = true
            $0.calendarPickerInterviewId = interviewId
        }
        await store.receive(\.calendarAccessResult) {
            $0.calendarAccessGranted = true
        }
        await store.receive(\.calendarEventsLoaded)
    }

    func testUnlinkCalendarEventClearsFields() async {
        let interviewId = UUID()
        var interview = InterviewRound(id: interviewId, round: 1)
        interview.calendarEventIdentifier = "event-123"
        interview.calendarEventTitle = "Phone Screen"
        let job = JobApplication.mock(interviews: [interview])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.unlinkCalendarEvent(interviewId: interviewId)) {
            $0.interviews[0].calendarEventIdentifier = nil
            $0.interviews[0].calendarEventTitle = nil
            $0.job.interviews[0].calendarEventIdentifier = nil
            $0.job.interviews[0].calendarEventTitle = nil
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testUnlinkCalendarEventOnlyAffectsCorrectRound() async {
        let interviewId1 = UUID()
        let interviewId2 = UUID()
        var interview1 = InterviewRound(id: interviewId1, round: 1)
        interview1.calendarEventIdentifier = "event-1"
        interview1.calendarEventTitle = "Phone Screen"
        var interview2 = InterviewRound(id: interviewId2, round: 2)
        interview2.calendarEventIdentifier = "event-2"
        interview2.calendarEventTitle = "Technical"
        let job = JobApplication.mock(interviews: [interview1, interview2])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.unlinkCalendarEvent(interviewId: interviewId1)) {
            $0.interviews[0].calendarEventIdentifier = nil
            $0.interviews[0].calendarEventTitle = nil
            $0.job.interviews[0].calendarEventIdentifier = nil
            $0.job.interviews[0].calendarEventTitle = nil
        }
        await store.receive(\.delegate.jobUpdated)

        // Second interview still has its calendar info
        XCTAssertEqual(store.state.interviews[1].calendarEventIdentifier, "event-2")
        XCTAssertEqual(store.state.interviews[1].calendarEventTitle, "Technical")
    }

    func testCalendarEventSelectedStoresIdentifierAndTitle() async {
        let interviewId = UUID()
        let existingDate = Date(timeIntervalSinceReferenceDate: 5000)
        let interview = InterviewRound(id: interviewId, round: 1, type: "Technical", date: existingDate)
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.showCalendarPicker = true
        state.calendarPickerInterviewId = interviewId

        let event = CalendarEvent(
            id: "event-abc",
            title: "Technical Interview",
            startDate: Date(timeIntervalSinceReferenceDate: 10000),
            endDate: Date(timeIntervalSinceReferenceDate: 13600),
            calendarName: "Work",
            calendarColor: "#FF0000",
            isAllDay: false
        )

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.calendarEventSelected(interviewId: interviewId, event: event)) {
            $0.interviews[0].calendarEventIdentifier = "event-abc"
            $0.interviews[0].calendarEventTitle = "Technical Interview"
            $0.job.interviews[0].calendarEventIdentifier = "event-abc"
            $0.job.interviews[0].calendarEventTitle = "Technical Interview"
            $0.showCalendarPicker = false
            $0.calendarPickerInterviewId = nil
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testCalendarEventSelectedAutoFillsDateWhenNil() async {
        let interviewId = UUID()
        let interview = InterviewRound(id: interviewId, round: 1, date: nil)
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.showCalendarPicker = true
        state.calendarPickerInterviewId = interviewId

        let eventDate = Date(timeIntervalSinceReferenceDate: 10000)
        let event = CalendarEvent(
            id: "event-xyz",
            title: "Phone Screen",
            startDate: eventDate,
            endDate: Date(timeIntervalSinceReferenceDate: 13600),
            calendarName: "Work",
            calendarColor: "#0000FF",
            isAllDay: false
        )

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.calendarEventSelected(interviewId: interviewId, event: event)) {
            $0.interviews[0].calendarEventIdentifier = "event-xyz"
            $0.interviews[0].calendarEventTitle = "Phone Screen"
            $0.interviews[0].date = eventDate
            $0.interviews[0].type = "Phone Screen"
            $0.job.interviews[0].calendarEventIdentifier = "event-xyz"
            $0.job.interviews[0].calendarEventTitle = "Phone Screen"
            $0.job.interviews[0].date = eventDate
            $0.job.interviews[0].type = "Phone Screen"
            $0.showCalendarPicker = false
            $0.calendarPickerInterviewId = nil
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testCalendarEventSelectedDoesNotOverwriteExistingDate() async {
        let interviewId = UUID()
        let existingDate = Date(timeIntervalSinceReferenceDate: 99999)
        let interview = InterviewRound(id: interviewId, round: 1, type: "Onsite", date: existingDate)
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.showCalendarPicker = true
        state.calendarPickerInterviewId = interviewId

        let event = CalendarEvent(
            id: "event-new",
            title: "Onsite",
            startDate: Date(timeIntervalSinceReferenceDate: 50000),
            endDate: Date(timeIntervalSinceReferenceDate: 53600),
            calendarName: "Work",
            calendarColor: "#00FF00",
            isAllDay: false
        )

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.calendarEventSelected(interviewId: interviewId, event: event)) {
            $0.interviews[0].calendarEventIdentifier = "event-new"
            $0.interviews[0].calendarEventTitle = "Onsite"
            // date stays at existingDate
            $0.job.interviews[0].calendarEventIdentifier = "event-new"
            $0.job.interviews[0].calendarEventTitle = "Onsite"
            $0.showCalendarPicker = false
            $0.calendarPickerInterviewId = nil
        }
        await store.receive(\.delegate.jobUpdated)

        XCTAssertEqual(store.state.interviews[0].date, existingDate)
    }

    func testCalendarEventSelectedAutoFillsTypeWhenEmpty() async {
        let interviewId = UUID()
        let existingDate = Date(timeIntervalSinceReferenceDate: 5000)
        let interview = InterviewRound(id: interviewId, round: 1, type: "", date: existingDate)
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.showCalendarPicker = true
        state.calendarPickerInterviewId = interviewId

        let event = CalendarEvent(
            id: "event-type",
            title: "Behavioral Round",
            startDate: Date(timeIntervalSinceReferenceDate: 10000),
            endDate: Date(timeIntervalSinceReferenceDate: 13600),
            calendarName: "Work",
            calendarColor: "#AAAAAA",
            isAllDay: false
        )

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.calendarEventSelected(interviewId: interviewId, event: event)) {
            $0.interviews[0].calendarEventIdentifier = "event-type"
            $0.interviews[0].calendarEventTitle = "Behavioral Round"
            $0.interviews[0].type = "Behavioral Round"
            $0.job.interviews[0].calendarEventIdentifier = "event-type"
            $0.job.interviews[0].calendarEventTitle = "Behavioral Round"
            $0.job.interviews[0].type = "Behavioral Round"
            $0.showCalendarPicker = false
            $0.calendarPickerInterviewId = nil
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testCalendarEventSelectedDoesNotOverwriteNonEmptyType() async {
        let interviewId = UUID()
        let existingDate = Date(timeIntervalSinceReferenceDate: 5000)
        let interview = InterviewRound(id: interviewId, round: 1, type: "Technical", date: existingDate)
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.showCalendarPicker = true
        state.calendarPickerInterviewId = interviewId

        let event = CalendarEvent(
            id: "event-notype",
            title: "General Interview",
            startDate: Date(timeIntervalSinceReferenceDate: 10000),
            endDate: Date(timeIntervalSinceReferenceDate: 13600),
            calendarName: "Work",
            calendarColor: "#BBBBBB",
            isAllDay: false
        )

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.calendarEventSelected(interviewId: interviewId, event: event)) {
            $0.interviews[0].calendarEventIdentifier = "event-notype"
            $0.interviews[0].calendarEventTitle = "General Interview"
            // type stays "Technical"
            $0.job.interviews[0].calendarEventIdentifier = "event-notype"
            $0.job.interviews[0].calendarEventTitle = "General Interview"
            $0.showCalendarPicker = false
            $0.calendarPickerInterviewId = nil
        }
        await store.receive(\.delegate.jobUpdated)

        XCTAssertEqual(store.state.interviews[0].type, "Technical")
    }

    func testCalendarAccessResultFalseSetsGrantedFalseNoFetch() async {
        let fetchCalled = LockIsolated(false)

        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        } withDependencies: {
            $0.calendarClient.fetchEvents = { _, _ in
                fetchCalled.setValue(true)
                return []
            }
        }

        await store.send(.calendarAccessResult(false)) {
            $0.calendarAccessGranted = false
        }

        XCTAssertFalse(fetchCalled.value)
    }

    func testCalendarAccessResultTrueSetsGrantedAndFetchesEvents() async {
        let mockEvent = CalendarEvent(
            id: "evt-1",
            title: "Interview",
            startDate: Date(timeIntervalSinceReferenceDate: 10000),
            endDate: Date(timeIntervalSinceReferenceDate: 13600),
            calendarName: "Work",
            calendarColor: "#FF0000",
            isAllDay: false
        )

        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        } withDependencies: {
            $0.calendarClient.fetchEvents = { _, _ in [mockEvent] }
        }

        await store.send(.calendarAccessResult(true)) {
            $0.calendarAccessGranted = true
        }
        await store.receive(\.calendarEventsLoaded) {
            $0.calendarEvents = [mockEvent]
        }
    }

    func testDismissCalendarPickerClosesAndClearsId() async {
        let interviewId = UUID()
        var state = JobDetailFeature.State(job: .mock())
        state.showCalendarPicker = true
        state.calendarPickerInterviewId = interviewId

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.dismissCalendarPicker) {
            $0.showCalendarPicker = false
            $0.calendarPickerInterviewId = nil
        }
    }

    func testCalendarSearchQueryChangedUpdatesState() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.calendarSearchQueryChanged("standup")) {
            $0.calendarSearchQuery = "standup"
        }
    }

    // MARK: - Calendar Sync

    func testRefreshLinkedCalendarEventsWithValidEvent() async {
        let interviewId = UUID()
        let eventDate = Date(timeIntervalSinceReferenceDate: 10000)
        var interview = InterviewRound(id: interviewId, round: 1, date: eventDate)
        interview.calendarEventIdentifier = "event-123"
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.calendarAccessGranted = true

        let matchingEvent = CalendarEvent(
            id: "event-123",
            title: "Interview",
            startDate: eventDate,
            endDate: Date(timeIntervalSinceReferenceDate: 13600),
            calendarName: "Work",
            calendarColor: "#FF0000",
            isAllDay: false
        )

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.calendarClient.fetchEvent = { _ in matchingEvent }
        }

        await store.send(.refreshLinkedCalendarEvents)
        await store.receive(\.calendarSyncResult)

        XCTAssertNil(store.state.calendarSyncWarnings[interviewId])
    }

    func testRefreshLinkedCalendarEventsWithDeletedEvent() async {
        let interviewId = UUID()
        var interview = InterviewRound(id: interviewId, round: 1, date: Date(timeIntervalSinceReferenceDate: 10000))
        interview.calendarEventIdentifier = "event-deleted"
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.calendarAccessGranted = true

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.calendarClient.fetchEvent = { _ in nil }
        }

        await store.send(.refreshLinkedCalendarEvents)
        await store.receive(\.calendarSyncResult) {
            $0.calendarSyncWarnings[interviewId] = .eventMissing
        }

        XCTAssertEqual(store.state.calendarSyncWarnings[interviewId], .eventMissing)
    }

    func testRefreshLinkedCalendarEventsWithRescheduledEvent() async {
        let interviewId = UUID()
        let originalDate = Date(timeIntervalSinceReferenceDate: 10000)
        let newDate = Date(timeIntervalSinceReferenceDate: 20000)
        var interview = InterviewRound(id: interviewId, round: 1, date: originalDate)
        interview.calendarEventIdentifier = "event-rescheduled"
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.calendarAccessGranted = true

        let rescheduledEvent = CalendarEvent(
            id: "event-rescheduled",
            title: "Interview",
            startDate: newDate,
            endDate: Date(timeIntervalSinceReferenceDate: 23600),
            calendarName: "Work",
            calendarColor: "#FF0000",
            isAllDay: false
        )

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.calendarClient.fetchEvent = { _ in rescheduledEvent }
        }

        await store.send(.refreshLinkedCalendarEvents)
        await store.receive(\.calendarSyncResult) {
            $0.calendarSyncWarnings[interviewId] = .eventRescheduled(newDate: newDate)
        }

        XCTAssertEqual(store.state.calendarSyncWarnings[interviewId], .eventRescheduled(newDate: newDate))
    }

    func testSyncInterviewDateFromCalendar() async {
        let interviewId = UUID()
        let originalDate = Date(timeIntervalSinceReferenceDate: 10000)
        let newDate = Date(timeIntervalSinceReferenceDate: 20000)
        var interview = InterviewRound(id: interviewId, round: 1, date: originalDate)
        interview.calendarEventIdentifier = "event-rescheduled"
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.calendarAccessGranted = true
        state.calendarSyncWarnings[interviewId] = .eventRescheduled(newDate: newDate)

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.syncInterviewDateFromCalendar(interviewId: interviewId)) {
            $0.interviews[0].date = newDate
            $0.job.interviews[0].date = newDate
            $0.calendarSyncWarnings.removeValue(forKey: interviewId)
        }
        await store.receive(\.delegate.jobUpdated)

        XCTAssertEqual(store.state.interviews[0].date, newDate)
        XCTAssertNil(store.state.calendarSyncWarnings[interviewId])
    }

    func testMultipleRoundsRefreshedIndependently() async {
        let idMissing = UUID()
        let idValid = UUID()
        let eventDate = Date(timeIntervalSinceReferenceDate: 10000)

        var roundMissing = InterviewRound(id: idMissing, round: 1, date: eventDate)
        roundMissing.calendarEventIdentifier = "event-missing"
        var roundValid = InterviewRound(id: idValid, round: 2, date: eventDate)
        roundValid.calendarEventIdentifier = "event-valid"

        let job = JobApplication.mock(interviews: [roundMissing, roundValid])
        var state = JobDetailFeature.State(job: job)
        state.calendarAccessGranted = true

        let validEvent = CalendarEvent(
            id: "event-valid",
            title: "Interview",
            startDate: eventDate,
            endDate: Date(timeIntervalSinceReferenceDate: 13600),
            calendarName: "Work",
            calendarColor: "#FF0000",
            isAllDay: false
        )

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.calendarClient.fetchEvent = { identifier in
                identifier == "event-missing" ? nil : validEvent
            }
        }
        store.exhaustivity = .off

        await store.send(.refreshLinkedCalendarEvents)
        await store.skipReceivedActions()

        XCTAssertEqual(store.state.calendarSyncWarnings[idMissing], .eventMissing)
        XCTAssertNil(store.state.calendarSyncWarnings[idValid])
    }

    func testRefreshSkippedWhenAccessNotGranted() async {
        let interviewId = UUID()
        var interview = InterviewRound(id: interviewId, round: 1, date: Date())
        interview.calendarEventIdentifier = "event-123"
        let job = JobApplication.mock(interviews: [interview])
        var state = JobDetailFeature.State(job: job)
        state.calendarAccessGranted = false

        let fetchCalled = LockIsolated(false)

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.calendarClient.fetchEvent = { _ in
                fetchCalled.setValue(true)
                return nil
            }
        }

        await store.send(.refreshLinkedCalendarEvents)

        XCTAssertFalse(fetchCalled.value)
        XCTAssertTrue(store.state.calendarSyncWarnings.isEmpty)
    }

    // MARK: - Chat History Codable

    func testChatMessageCodableRoundTrip() throws {
        let msg = ChatMessage(role: .assistant, content: "Test response")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.id, msg.id)
        XCTAssertEqual(decoded.role, .assistant)
        XCTAssertEqual(decoded.content, "Test response")
    }

    func testJobApplicationChatHistoryRoundTrip() throws {
        var job = JobApplication.mock()
        job.chatHistory = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi!"),
        ]
        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(JobApplication.self, from: data)
        XCTAssertEqual(decoded.chatHistory.count, 2)
        XCTAssertEqual(decoded.chatHistory[0].role, .user)
        XCTAssertEqual(decoded.chatHistory[1].role, .assistant)
    }

    func testJobApplicationEmptyChatHistoryNotEncoded() throws {
        let job = JobApplication.mock()
        let data = try JSONEncoder().encode(job)
        let json = String(data: data, encoding: .utf8)!
        // Empty chatHistory should not be in JSON (we skip encoding it)
        XCTAssertFalse(json.contains("chatHistory"))
    }

    // MARK: - moveJobRequested

    func testMoveJobRequestedWithNoIncompleteTasks() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock(status: .wishlist))) {
            JobDetailFeature()
        }

        store.exhaustivity = .off
        await store.send(.moveJobRequested(.applied))
        await store.receive(\.moveJob)

        XCTAssertEqual(store.state.job.status, .applied)
        XCTAssertFalse(store.state.showIncompleteTasksAlert)
    }

    func testMoveJobRequestedWithIncompleteTasksShowsAlert() async {
        let task = SubTask(title: "Research company", isCompleted: false, forStatus: .wishlist)
        let job = JobApplication.mock(status: .wishlist, tasks: [task])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.moveJobRequested(.applied)) {
            $0.pendingStatusChange = .applied
            $0.showIncompleteTasksAlert = true
        }

        XCTAssertEqual(store.state.job.status, .wishlist)
    }

    func testMoveJobAlertContinueTransitionsStatus() async {
        let task = SubTask(title: "Research company", isCompleted: false, forStatus: .wishlist)
        let job = JobApplication.mock(status: .wishlist, tasks: [task])
        var state = JobDetailFeature.State(job: job)
        state.pendingStatusChange = .applied
        state.showIncompleteTasksAlert = true

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        store.exhaustivity = .off
        await store.send(.moveJobAlertContinue)
        await store.receive(\.moveJob)

        XCTAssertEqual(store.state.job.status, .applied)
        XCTAssertFalse(store.state.showIncompleteTasksAlert)
        XCTAssertNil(store.state.pendingStatusChange)
    }

    func testMoveJobAlertCancelLeavesStatusUnchanged() async {
        let task = SubTask(title: "Research company", isCompleted: false, forStatus: .wishlist)
        let job = JobApplication.mock(status: .wishlist, tasks: [task])
        var state = JobDetailFeature.State(job: job)
        state.pendingStatusChange = .applied
        state.showIncompleteTasksAlert = true

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.moveJobAlertCancel) {
            $0.pendingStatusChange = nil
            $0.showIncompleteTasksAlert = false
        }

        XCTAssertEqual(store.state.job.status, .wishlist)
    }

    // MARK: - Task CRUD

    func testToggleTaskCompletesIt() async {
        let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let task = SubTask(id: taskID, title: "Research company", isCompleted: false, forStatus: .wishlist)
        let job = JobApplication.mock(tasks: [task])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.toggleTask(taskID)) {
            $0.job.tasks[0].isCompleted = true
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testToggleTaskUnchecksCompleted() async {
        let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let task = SubTask(id: taskID, title: "Research company", isCompleted: true, forStatus: .wishlist)
        let job = JobApplication.mock(tasks: [task])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.toggleTask(taskID)) {
            $0.job.tasks[0].isCompleted = false
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testDeleteTask() async {
        let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let task = SubTask(id: taskID, title: "Research company", isCompleted: false, forStatus: .wishlist)
        let job = JobApplication.mock(tasks: [task])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }

        await store.send(.deleteTask(taskID)) {
            $0.job.tasks = []
        }
        await store.receive(\.delegate.jobUpdated)
    }

    func testAddTaskTapped() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.addTaskTapped) {
            $0.isAddingTask = true
        }
    }

    func testSaveNewTask() async {
        var state = JobDetailFeature.State(job: .mock(status: .wishlist))
        state.isAddingTask = true
        state.newTaskText = "My custom task"

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.saveNewTask)
        await store.receive(\.delegate.jobUpdated)

        XCTAssertFalse(store.state.isAddingTask)
        XCTAssertEqual(store.state.newTaskText, "")
        XCTAssertEqual(store.state.job.tasks.count, 1)
        XCTAssertEqual(store.state.job.tasks[0].title, "My custom task")
        XCTAssertFalse(store.state.job.tasks[0].isCompleted)
        XCTAssertEqual(store.state.job.tasks[0].forStatus, .wishlist)
    }

    func testSaveNewTaskWithEmptyTextCancels() async {
        var state = JobDetailFeature.State(job: .mock())
        state.isAddingTask = true
        state.newTaskText = "   "

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.saveNewTask) {
            $0.isAddingTask = false
            $0.newTaskText = ""
        }
    }

    func testCancelNewTask() async {
        var state = JobDetailFeature.State(job: .mock())
        state.isAddingTask = true
        state.newTaskText = "partial"

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.cancelNewTask) {
            $0.isAddingTask = false
            $0.newTaskText = ""
        }
    }

    func testAddSuggestedTask() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock(status: .wishlist))) {
            JobDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.addSuggestedTask("Research the company"))
        await store.receive(\.delegate.jobUpdated)

        XCTAssertEqual(store.state.job.tasks.count, 1)
        XCTAssertEqual(store.state.job.tasks[0].title, "Research the company")
        XCTAssertFalse(store.state.job.tasks[0].isCompleted)
        XCTAssertEqual(store.state.job.tasks[0].forStatus, .wishlist)
    }

    func testNewTaskTextChanged() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.newTaskTextChanged("Schedule follow-up call")) {
            $0.newTaskText = "Schedule follow-up call"
        }
    }

    func testMoveJobRequestedWithCompletedTasksProceedsImmediately() async {
        let task = SubTask(title: "Research the company", isCompleted: true, forStatus: .wishlist)
        let job = JobApplication.mock(status: .wishlist, tasks: [task])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.moveJobRequested(.applied))
        await store.receive(\.moveJob)

        XCTAssertEqual(store.state.job.status, .applied)
        XCTAssertFalse(store.state.showIncompleteTasksAlert)
    }
}
