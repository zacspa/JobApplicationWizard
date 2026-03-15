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

    func testDeleteLastInterviewFromMultiple() async {
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

    // MARK: - AI: sendMessage

    func testSendMessageWithChatMode() async {
        var state = JobDetailFeature.State(job: .mock(), apiKey: "test-key")
        state.aiInput = "Hello"

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.claudeClient.chat = { _, _, _ in
                ("AI response", AITokenUsage(inputTokens: 10, outputTokens: 20))
            }
        }
        store.exhaustivity = .off

        await store.send(.sendMessage)
        await store.receive(\.aiResponseReceived)

        XCTAssertFalse(store.state.aiIsLoading)
        XCTAssertEqual(store.state.chatMessages.count, 2)
        XCTAssertEqual(store.state.chatMessages[0].role, .user)
        XCTAssertEqual(store.state.chatMessages[0].content, "Hello")
        XCTAssertEqual(store.state.chatMessages[1].role, .assistant)
        XCTAssertEqual(store.state.chatMessages[1].content, "AI response")
        XCTAssertEqual(store.state.aiTokenUsage, AITokenUsage(inputTokens: 10, outputTokens: 20))
        XCTAssertEqual(store.state.aiInput, "")
    }

    func testSendMessagePlainText() async {
        var state = JobDetailFeature.State(job: .mock(), apiKey: "test-key")
        state.aiInput = "My resume"

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.claudeClient.chat = { _, _, _ in
                ("Tailored", AITokenUsage(inputTokens: 5, outputTokens: 10))
            }
        }
        store.exhaustivity = .off

        await store.send(.sendMessage)
        await store.receive(\.aiResponseReceived)

        XCTAssertEqual(store.state.chatMessages.count, 2)
        // Messages are now sent as-is (no mode preamble)
        XCTAssertEqual(store.state.chatMessages[0].content, "My resume")
        XCTAssertEqual(store.state.chatMessages[1].content, "Tailored")
    }

    func testSendMessageAIResponseError() async {
        var state = JobDetailFeature.State(job: .mock(), apiKey: "test-key")
        state.aiInput = "Hello"

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.claudeClient.chat = { _, _, _ in
                throw AIError.noAPIKey
            }
        }
        store.exhaustivity = .off

        await store.send(.sendMessage)
        await store.receive(\.aiResponseReceived)

        XCTAssertFalse(store.state.aiIsLoading)
        XCTAssertEqual(store.state.aiError, AIError.noAPIKey.localizedDescription)
    }

    func testSendMessageEmptyInputDoesNothing() async {
        var state = JobDetailFeature.State(job: .mock(), apiKey: "test-key")
        state.aiInput = "   "

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.sendMessage)
        // No state changes, no effects
    }

    // MARK: - AI: clearChat

    func testClearChat() async {
        var state = JobDetailFeature.State(job: .mock())
        state.chatMessages = [ChatMessage(role: .user, content: "test")]
        state.aiInput = "something"
        state.aiError = "some error"
        state.aiTokenUsage = AITokenUsage(inputTokens: 100, outputTokens: 200)

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        }

        await store.send(.clearChat) {
            $0.chatMessages = []
            $0.aiInput = ""
            $0.aiError = nil
            $0.aiTokenUsage = .zero
            $0.job.chatHistory = []
        }
        await store.receive(\.delegate.jobUpdated)
    }

    // MARK: - AI: response accumulates token usage

    func testAIResponseAccumulatesTokenUsage() async {
        var state = JobDetailFeature.State(job: .mock(), apiKey: "test-key")
        state.aiTokenUsage = AITokenUsage(inputTokens: 100, outputTokens: 200)
        state.aiInput = "More"

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.claudeClient.chat = { _, _, _ in
                ("Response", AITokenUsage(inputTokens: 50, outputTokens: 75))
            }
        }
        store.exhaustivity = .off

        await store.send(.sendMessage)
        await store.receive(\.aiResponseReceived)

        XCTAssertEqual(store.state.aiTokenUsage.inputTokens, 150)
        XCTAssertEqual(store.state.aiTokenUsage.outputTokens, 275)
        XCTAssertEqual(store.state.chatMessages.count, 2)
        XCTAssertEqual(store.state.chatMessages.last?.content, "Response")
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

    // MARK: - System Prompt Builder

    func testBuildSystemPromptIncludesJobContext() {
        let job = JobApplication.mock(
            company: "TestCo",
            title: "Senior Dev",
            jobDescription: "Build things"
        )
        let prompt = JobDetailFeature.buildSystemPrompt(job: job, profile: UserProfile())

        XCTAssertTrue(prompt.contains("Senior Dev"))
        XCTAssertTrue(prompt.contains("TestCo"))
        XCTAssertTrue(prompt.contains("Build things"))
        XCTAssertTrue(prompt.contains("expert career coach"))
    }

    func testBuildSystemPromptIncludesUserProfile() {
        let job = JobApplication.mock()
        var profile = UserProfile()
        profile.name = "Alice"
        profile.skills = ["Swift", "Python"]
        profile.resume = "10 years experience"

        let prompt = JobDetailFeature.buildSystemPrompt(job: job, profile: profile)

        XCTAssertTrue(prompt.contains("Alice"))
        XCTAssertTrue(prompt.contains("Swift, Python"))
        XCTAssertTrue(prompt.contains("10 years experience"))
    }

    func testBuildSystemPromptOmitsEmptyProfile() {
        let job = JobApplication.mock()
        let prompt = JobDetailFeature.buildSystemPrompt(job: job, profile: UserProfile())

        XCTAssertFalse(prompt.contains("About the candidate"))
    }

    func testBuildSystemPromptIncludesContacts() {
        let job = JobApplication.mock(
            contacts: [Contact(name: "Bob", title: "Recruiter", notes: "Met at conference")]
        )
        let prompt = JobDetailFeature.buildSystemPrompt(job: job, profile: UserProfile())

        XCTAssertTrue(prompt.contains("Bob"))
        XCTAssertTrue(prompt.contains("Recruiter"))
        XCTAssertTrue(prompt.contains("Met at conference"))
    }

    func testBuildSystemPromptIncludesInterviews() {
        let job = JobApplication.mock(
            interviews: [InterviewRound(round: 1, type: "Technical", interviewers: "Jane")]
        )
        let prompt = JobDetailFeature.buildSystemPrompt(job: job, profile: UserProfile())

        XCTAssertTrue(prompt.contains("Round 1"))
        XCTAssertTrue(prompt.contains("Technical"))
        XCTAssertTrue(prompt.contains("Jane"))
    }

    func testBuildSystemPromptIncludesNotes() {
        let job = JobApplication.mock(
            noteCards: [Note(title: "Salary Research", body: "Glassdoor says $150k")]
        )
        let prompt = JobDetailFeature.buildSystemPrompt(job: job, profile: UserProfile())

        XCTAssertTrue(prompt.contains("Salary Research"))
        XCTAssertTrue(prompt.contains("Glassdoor says $150k"))
    }

    func testBuildSystemPromptIncludesActiveTab() {
        let job = JobApplication.mock()
        let prompt = JobDetailFeature.buildSystemPrompt(
            job: job, profile: UserProfile(), activeTab: .interviews
        )

        XCTAssertTrue(prompt.contains("Interviews tab"))
    }

    func testBuildSystemPromptIncludesRecentActivity() {
        let job = JobApplication.mock()
        let prompt = JobDetailFeature.buildSystemPrompt(job: job, profile: UserProfile())

        XCTAssertTrue(prompt.contains("Recent Activity"))
        XCTAssertTrue(prompt.contains("Added:"))
    }

    func testBuildSystemPromptIncludesLabelsAndSalary() {
        let job = JobApplication.mock(
            salary: "$120k-150k",
            labels: [JobLabel(name: "Remote", colorHex: "#34C759")]
        )
        let prompt = JobDetailFeature.buildSystemPrompt(job: job, profile: UserProfile())

        XCTAssertTrue(prompt.contains("$120k-150k"))
        XCTAssertTrue(prompt.contains("Remote"))
    }

    func testBuildSystemPromptIncludesChatHistoryTail() {
        let job = JobApplication.mock()
        let history = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there!"),
        ]
        let prompt = JobDetailFeature.buildSystemPrompt(
            job: job, profile: UserProfile(), chatHistory: history
        )

        XCTAssertTrue(prompt.contains("Previous conversation"))
        XCTAssertTrue(prompt.contains("User: Hello"))
        XCTAssertTrue(prompt.contains("Assistant: Hi there!"))
    }

    // MARK: - AI Panel

    func testToggleAIPanel() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.toggleAIPanel) {
            $0.aiPanelOpen = true
        }
        await store.send(.toggleAIPanel) {
            $0.aiPanelOpen = false
        }
    }

    func testOpenAIPanelWithPrompt() async {
        let store = TestStore(initialState: JobDetailFeature.State(job: .mock())) {
            JobDetailFeature()
        }

        await store.send(.openAIPanelWithPrompt("Draft a cover letter")) {
            $0.aiPanelOpen = true
            $0.aiInput = "Draft a cover letter"
        }
    }

    // MARK: - Chat History Persistence

    func testChatHistoryLoadedFromJob() {
        let history = [ChatMessage(role: .user, content: "Hello")]
        let job = JobApplication.mock(chatHistory: history)
        let state = JobDetailFeature.State(job: job)
        XCTAssertEqual(state.chatMessages.count, 1)
        XCTAssertEqual(state.chatMessages[0].content, "Hello")
    }

    func testChatHistorySyncedOnResponse() async {
        var state = JobDetailFeature.State(job: .mock(), apiKey: "test-key")
        state.aiInput = "Hello"

        let store = TestStore(initialState: state) {
            JobDetailFeature()
        } withDependencies: {
            $0.claudeClient.chat = { _, _, _ in
                ("Response", AITokenUsage(inputTokens: 10, outputTokens: 20))
            }
        }
        store.exhaustivity = .off

        await store.send(.sendMessage)
        await store.receive(\.aiResponseReceived)

        // Chat history should be persisted to job
        XCTAssertEqual(store.state.job.chatHistory.count, 2)
        XCTAssertEqual(store.state.job.chatHistory[0].content, "Hello")
        XCTAssertEqual(store.state.job.chatHistory[1].content, "Response")
    }

    // MARK: - ChatMessage Codable

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
}
