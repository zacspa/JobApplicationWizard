import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class CuttleFeatureTests: XCTestCase {

    // MARK: - Helpers

    private static let jobA = JobApplication.mock(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
        company: "Alpha", title: "Engineer", status: .interview
    )
    private static let jobB = JobApplication.mock(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!,
        company: "Beta", title: "Manager", status: .rejected
    )

    // MARK: - Toggle Expanded / Collapse

    func testToggleExpanded() async {
        let store = TestStore(initialState: CuttleFeature.State()) { CuttleFeature() }

        await store.send(.toggleExpanded) { $0.isExpanded = true }
        await store.send(.toggleExpanded) { $0.isExpanded = false }
    }

    func testCollapse() async {
        var state = CuttleFeature.State()
        state.isExpanded = true
        let store = TestStore(initialState: state) { CuttleFeature() }

        await store.send(.collapse) { $0.isExpanded = false }
    }

    // MARK: - Drag Changed

    func testDragChangedUpdatesPositionAndMood() async {
        let store = TestStore(initialState: CuttleFeature.State()) { CuttleFeature() }

        await store.send(.dragChanged(CGPoint(x: 100, y: 200))) {
            $0.isDragging = true
            $0.mood = .listening
            $0.position = CGPoint(x: 100, y: 200)
        }
    }

    func testDragChangedDetectsDropZone() async {
        var state = CuttleFeature.State()
        state.dropZones = [
            DropZone(id: "global", frame: CGRect(x: 50, y: 50, width: 100, height: 40), context: .global)
        ]
        let store = TestStore(initialState: state) { CuttleFeature() }

        await store.send(.dragChanged(CGPoint(x: 100, y: 70))) {
            $0.isDragging = true
            $0.mood = .listening
            $0.position = CGPoint(x: 100, y: 70)
            $0.pendingContext = .global
        }
    }

    func testDragChangedPrefersSpecificDropZone() async {
        let jobId = Self.jobA.id
        var state = CuttleFeature.State()
        // Overlapping zones: a status zone and a job zone inside it
        state.dropZones = [
            DropZone(id: "status-Interview", frame: CGRect(x: 0, y: 0, width: 300, height: 200), context: .status(.interview)),
            DropZone(id: "job-A", frame: CGRect(x: 50, y: 50, width: 100, height: 60), context: .job(jobId)),
        ]
        let store = TestStore(initialState: state) { CuttleFeature() }

        // Drag into the overlapping area; job should win over status
        await store.send(.dragChanged(CGPoint(x: 80, y: 70))) {
            $0.isDragging = true
            $0.mood = .listening
            $0.position = CGPoint(x: 80, y: 70)
            $0.pendingContext = .job(jobId)
        }
    }

    func testDragChangedClearsPendingWhenOutsideZones() async {
        var state = CuttleFeature.State()
        state.isDragging = true
        state.pendingContext = .global
        state.dropZones = [
            DropZone(id: "global", frame: CGRect(x: 50, y: 50, width: 100, height: 40), context: .global)
        ]
        let store = TestStore(initialState: state) { CuttleFeature() }

        await store.send(.dragChanged(CGPoint(x: 500, y: 500))) {
            $0.mood = .listening
            $0.position = CGPoint(x: 500, y: 500)
            $0.pendingContext = nil
        }
    }

    // MARK: - Drag Ended

    func testDragEndedSwitchesSilentlyWithEmptyChat() async {
        var state = CuttleFeature.State()
        state.isDragging = true
        state.pendingContext = .status(.interview)
        state.currentContext = .global
        state.chatMessages = []
        let store = TestStore(initialState: state) { CuttleFeature() }
        store.exhaustivity = .off

        await store.send(.dragEnded(CGPoint(x: 100, y: 100)))

        XCTAssertEqual(store.state.currentContext, .status(.interview))
        XCTAssertFalse(store.state.isDragging)
        XCTAssertNil(store.state.pendingContext)
    }

    func testDragEndedShowsAlertWithActiveChat() async {
        var state = CuttleFeature.State()
        state.isDragging = true
        state.pendingContext = .status(.rejected)
        state.currentContext = .global
        state.chatMessages = [ChatMessage(role: .user, content: "Hello")]
        let store = TestStore(initialState: state) { CuttleFeature() }

        await store.send(.dragEnded(CGPoint(x: 100, y: 100))) {
            $0.isDragging = false
            $0.pendingContext = nil
            $0.alertPendingContext = .status(.rejected)
            $0.showContextTransitionAlert = true
            $0.mood = .transitioning
        }
    }

    func testDragEndedCollapsesWhenExpanded() async {
        var state = CuttleFeature.State()
        state.isDragging = true
        state.isExpanded = true
        state.pendingContext = .global
        state.currentContext = .global
        state.chatMessages = []
        let store = TestStore(initialState: state) { CuttleFeature() }
        store.exhaustivity = .off

        await store.send(.dragEnded(CGPoint(x: 100, y: 100)))

        XCTAssertFalse(store.state.isExpanded)
    }

    func testDragEndedClampsWhenNoPendingContext() async {
        var state = CuttleFeature.State()
        state.isDragging = true
        state.pendingContext = nil
        state.windowSize = CGSize(width: 800, height: 600)
        state.position = CGPoint(x: 900, y: 700)
        let store = TestStore(initialState: state) { CuttleFeature() }

        await store.send(.dragEnded(CGPoint(x: 900, y: 700))) {
            $0.isDragging = false
            $0.mood = .idle
            $0.position = CGPoint(x: 776, y: 576)  // clamped: 800 - 24, 600 - 24
        }
    }

    // MARK: - Context Transition (carry / fresh)

    func testContextTransitionCarryKeepsMessages() async {
        var state = CuttleFeature.State()
        state.alertPendingContext = .status(.interview)
        state.showContextTransitionAlert = true
        state.currentContext = .global
        state.chatMessages = [ChatMessage(role: .user, content: "Hello")]
        state.isLoading = true
        let store = TestStore(initialState: state) { CuttleFeature() }
        store.exhaustivity = .off

        await store.send(.contextTransitionConfirmed(carry: true))

        XCTAssertEqual(store.state.currentContext, .status(.interview))
        XCTAssertFalse(store.state.showContextTransitionAlert)
        XCTAssertNil(store.state.alertPendingContext)
        XCTAssertFalse(store.state.isLoading)
        // Messages carried over
        XCTAssertEqual(store.state.chatMessages.count, 1)
        XCTAssertEqual(store.state.chatMessages[0].content, "Hello")
    }

    func testContextTransitionFreshLoadsNewHistory() async {
        var state = CuttleFeature.State()
        state.alertPendingContext = .status(.interview)
        state.showContextTransitionAlert = true
        state.currentContext = .global
        state.chatMessages = [ChatMessage(role: .user, content: "Old message")]
        state.globalChatHistory = []
        state.statusChatHistories = ["Interview": [ChatMessage(role: .user, content: "Prev interview chat")]]
        let store = TestStore(initialState: state) { CuttleFeature() }
        store.exhaustivity = .off

        await store.send(.contextTransitionConfirmed(carry: false))

        XCTAssertEqual(store.state.currentContext, .status(.interview))
        // Old message was saved to global, new history loaded
        XCTAssertEqual(store.state.globalChatHistory.count, 1)
        XCTAssertEqual(store.state.globalChatHistory[0].content, "Old message")
        XCTAssertEqual(store.state.chatMessages.count, 1)
        XCTAssertEqual(store.state.chatMessages[0].content, "Prev interview chat")
    }

    func testCancelContextTransitionSnapsBack() async {
        var state = CuttleFeature.State()
        state.alertPendingContext = .status(.interview)
        state.showContextTransitionAlert = true
        state.currentContext = .global
        state.dropZones = [
            DropZone(id: "global", frame: CGRect(x: 50, y: 50, width: 100, height: 40), context: .global)
        ]
        let store = TestStore(initialState: state) { CuttleFeature() }

        await store.send(.cancelContextTransition) {
            $0.showContextTransitionAlert = false
            $0.alertPendingContext = nil
            $0.mood = .idle
            $0.position = CGPoint(x: 100, y: 70)  // snapped to global zone center
        }
    }

    // MARK: - Switch Context (silent)

    func testSwitchContextSavesAndLoadsHistory() async {
        var state = CuttleFeature.State()
        state.currentContext = .global
        state.chatMessages = [ChatMessage(role: .user, content: "Global msg")]
        state.statusChatHistories = ["Interview": [ChatMessage(role: .assistant, content: "Interview msg")]]
        let store = TestStore(initialState: state) { CuttleFeature() }
        store.exhaustivity = .off

        await store.send(.switchContext(.status(.interview)))

        // Old messages saved to global
        XCTAssertEqual(store.state.globalChatHistory.count, 1)
        XCTAssertEqual(store.state.globalChatHistory[0].content, "Global msg")
        // New messages loaded from interview
        XCTAssertEqual(store.state.chatMessages.count, 1)
        XCTAssertEqual(store.state.chatMessages[0].content, "Interview msg")
        XCTAssertEqual(store.state.currentContext, .status(.interview))
        XCTAssertFalse(store.state.acpSentSystemPrompt)
    }

    func testSwitchContextCancelsInFlightAI() async {
        var state = CuttleFeature.State()
        state.currentContext = .global
        state.isLoading = true
        let store = TestStore(initialState: state) { CuttleFeature() }
        store.exhaustivity = .off

        await store.send(.switchContext(.status(.offer)))

        XCTAssertFalse(store.state.isLoading)
        XCTAssertEqual(store.state.currentContext, .status(.offer))
    }

    // MARK: - Send Message

    func testSendMessageAppendsAndCallsAPI() async {
        var state = CuttleFeature.State()
        state.apiKey = "test-key"
        let store = TestStore(initialState: state) {
            CuttleFeature()
        } withDependencies: {
            $0.claudeClient.chat = { _, _, _, _ in
                ("AI response", AITokenUsage(inputTokens: 10, outputTokens: 20), nil)
            }
        }
        store.exhaustivity = .off

        await store.send(.sendMessage("Hello"))
        await store.receive(\.aiResponseReceived)

        XCTAssertFalse(store.state.isLoading)
        XCTAssertEqual(store.state.chatMessages.count, 2)
        XCTAssertEqual(store.state.chatMessages[0].role, .user)
        XCTAssertEqual(store.state.chatMessages[0].content, "Hello")
        XCTAssertEqual(store.state.chatMessages[1].role, .assistant)
        XCTAssertEqual(store.state.chatMessages[1].content, "AI response")
        XCTAssertEqual(store.state.chatInput, "")
    }

    func testSendMessageEmptyDoesNothing() async {
        let store = TestStore(initialState: CuttleFeature.State()) { CuttleFeature() }
        await store.send(.sendMessage("   "))
    }

    func testSendMessageAccumulatesTokens() async {
        var state = CuttleFeature.State()
        state.apiKey = "test-key"
        state.tokenUsage = AITokenUsage(inputTokens: 100, outputTokens: 200)
        let store = TestStore(initialState: state) {
            CuttleFeature()
        } withDependencies: {
            $0.claudeClient.chat = { _, _, _, _ in
                ("Response", AITokenUsage(inputTokens: 50, outputTokens: 75), nil)
            }
        }
        store.exhaustivity = .off

        await store.send(.sendMessage("More"))
        await store.receive(\.aiResponseReceived)

        XCTAssertEqual(store.state.tokenUsage.inputTokens, 150)
        XCTAssertEqual(store.state.tokenUsage.outputTokens, 275)
    }

    func testSendMessageErrorSetsErrorAndSavesHistory() async {
        var state = CuttleFeature.State()
        state.apiKey = "key"
        let store = TestStore(initialState: state) {
            CuttleFeature()
        } withDependencies: {
            $0.claudeClient.chat = { _, _, _, _ in throw AIError.noAPIKey }
        }
        store.exhaustivity = .off

        await store.send(.sendMessage("Hello"))
        await store.receive(\.aiResponseReceived)

        XCTAssertFalse(store.state.isLoading)
        XCTAssertNotNil(store.state.error)
        // User message preserved in global history (via saveChatHistory on failure)
        XCTAssertEqual(store.state.globalChatHistory.count, 1)
    }

    // MARK: - AI Response with Job Context (delegate)

    func testAIResponseInJobContextSendsDelegate() async {
        let job = Self.jobA
        var state = CuttleFeature.State()
        state.currentContext = .job(job.id)
        state.jobs = [job]
        state.apiKey = "test-key"
        let store = TestStore(initialState: state) {
            CuttleFeature()
        } withDependencies: {
            $0.claudeClient.chat = { _, _, _, _ in
                ("AI response", AITokenUsage(inputTokens: 10, outputTokens: 20), nil)
            }
        }
        store.exhaustivity = .off

        await store.send(.sendMessage("Analyze my fit"))
        await store.receive(\.aiResponseReceived)
        // Should receive a delegate to persist job chat
        await store.receive(\.delegate.jobChatUpdated)

        XCTAssertEqual(store.state.chatMessages.count, 2)
    }

    // MARK: - Clear Chat

    func testClearChat() async {
        var state = CuttleFeature.State()
        state.currentContext = .global
        state.chatMessages = [ChatMessage(role: .user, content: "test")]
        state.chatInput = "something"
        state.error = "some error"
        state.tokenUsage = AITokenUsage(inputTokens: 100, outputTokens: 200)
        state.acpSentSystemPrompt = true
        let store = TestStore(initialState: state) { CuttleFeature() }

        await store.send(.clearChat) {
            $0.chatMessages = []
            $0.chatInput = ""
            $0.error = nil
            $0.tokenUsage = .zero
            $0.acpSentSystemPrompt = false
            $0.globalChatHistory = []
        }
    }

    // MARK: - Apply Suggestion

    func testApplySuggestionSendsMessage() async {
        var state = CuttleFeature.State()
        state.apiKey = "test-key"
        let store = TestStore(initialState: state) {
            CuttleFeature()
        } withDependencies: {
            $0.claudeClient.chat = { _, _, _, _ in
                ("Response", AITokenUsage(inputTokens: 10, outputTokens: 20), nil)
            }
        }
        store.exhaustivity = .off

        await store.send(.applySuggestion("Analyze my fit"))
        // applySuggestion dispatches sendMessage, which we need to receive
        await store.receive(\.sendMessage)
        await store.receive(\.aiResponseReceived)

        XCTAssertEqual(store.state.chatMessages.count, 2)
        XCTAssertEqual(store.state.chatMessages[0].content, "Analyze my fit")
    }

    // MARK: - Restore From Settings

    func testRestoreFromSettings() async {
        let interviewMsg = ChatMessage(role: .assistant, content: "Interview chat")
        let globalHistory = [ChatMessage(role: .user, content: "Saved")]
        let statusHistories = ["Interview": [interviewMsg]]
        let store = TestStore(initialState: CuttleFeature.State()) { CuttleFeature() }

        await store.send(.restoreFromSettings(.status(.interview), globalHistory, statusHistories)) {
            $0.currentContext = .status(.interview)
            $0.globalChatHistory = globalHistory
            $0.statusChatHistories = statusHistories
            $0.chatMessages = [interviewMsg]
            $0.tokenUsage = .zero
            $0.error = nil
        }
    }

    func testRestoreGlobalContext() async {
        let globalHistory = [ChatMessage(role: .user, content: "Global msg")]
        let store = TestStore(initialState: CuttleFeature.State()) { CuttleFeature() }

        await store.send(.restoreFromSettings(.global, globalHistory, [:])) {
            $0.currentContext = .global
            $0.globalChatHistory = globalHistory
            $0.chatMessages = globalHistory
            $0.tokenUsage = .zero
            $0.error = nil
        }
    }

    // MARK: - Position At Drop Zone

    func testPositionAtDropZone() async {
        var state = CuttleFeature.State()
        state.currentContext = .global
        state.dropZones = [
            DropZone(id: "global", frame: CGRect(x: 100, y: 50, width: 80, height: 30), context: .global)
        ]
        let store = TestStore(initialState: state) { CuttleFeature() }

        await store.send(.positionAtDropZone) {
            $0.position = CGPoint(x: 140, y: 65)  // center of the drop zone
        }
    }

    // MARK: - Drop Zones Updated

    func testDropZonesUpdated() async {
        let zones = [
            DropZone(id: "global", frame: CGRect(x: 0, y: 0, width: 100, height: 40), context: .global)
        ]
        let store = TestStore(initialState: CuttleFeature.State()) { CuttleFeature() }

        await store.send(.dropZonesUpdated(zones)) {
            $0.dropZones = zones
            // Snaps to the docked zone (global) center
            $0.position = CGPoint(x: 50, y: 20)
        }
    }

    // MARK: - Window Size Changed

    func testWindowSizeChangedClampsPosition() async {
        var state = CuttleFeature.State()
        state.position = CGPoint(x: 900, y: 700)
        let store = TestStore(initialState: state) { CuttleFeature() }

        await store.send(.windowSizeChanged(CGSize(width: 800, height: 600))) {
            $0.windowSize = CGSize(width: 800, height: 600)
            $0.position = CGPoint(x: 776, y: 576)
        }
    }

    // MARK: - Chat History Pruning

    func testSaveChatHistoryPrunesAt100Messages() async {
        var state = CuttleFeature.State()
        state.currentContext = .global
        // Create 110 messages
        state.chatMessages = (0..<110).map { i in
            ChatMessage(role: .user, content: "Message \(i)")
        }
        let store = TestStore(initialState: state) { CuttleFeature() }

        await store.send(.clearChat) {
            $0.chatMessages = []
            $0.chatInput = ""
            $0.error = nil
            $0.tokenUsage = .zero
            $0.acpSentSystemPrompt = false
            $0.globalChatHistory = []
        }

        // Verify pruning works by sending messages and checking saved history
        // The clearChat above saves [] to globalChatHistory (pruned from 0).
        // For a more direct test, let's switch context after filling messages.
    }

    func testSavePrunesOnContextSwitch() async {
        var state = CuttleFeature.State()
        state.currentContext = .global
        state.chatMessages = (0..<110).map { i in
            ChatMessage(role: .user, content: "Message \(i)")
        }
        let store = TestStore(initialState: state) { CuttleFeature() }
        store.exhaustivity = .off

        await store.send(.switchContext(.status(.interview)))

        // Global history should be pruned to last 100
        XCTAssertEqual(store.state.globalChatHistory.count, 100)
        XCTAssertEqual(store.state.globalChatHistory.first?.content, "Message 10")
        XCTAssertEqual(store.state.globalChatHistory.last?.content, "Message 109")
    }

    // MARK: - CuttleContext Properties

    func testCuttleContextLabel() {
        XCTAssertEqual(CuttleContext.global.label, "All Jobs")
        XCTAssertEqual(CuttleContext.status(.interview).label, "Interview")
        XCTAssertEqual(CuttleContext.status(.rejected).label, "Rejected")
        XCTAssertEqual(CuttleContext.job(UUID()).label, "Job")
    }

    func testCuttleContextDisplayLabel() {
        let job = Self.jobA
        let jobs = [job, Self.jobB]

        XCTAssertEqual(CuttleContext.global.displayLabel(jobs: jobs), "All Jobs")
        XCTAssertEqual(CuttleContext.status(.interview).displayLabel(jobs: jobs), "Interview (1)")
        XCTAssertEqual(CuttleContext.status(.rejected).displayLabel(jobs: jobs), "Rejected (1)")
        XCTAssertEqual(CuttleContext.status(.wishlist).displayLabel(jobs: jobs), "Wishlist (0)")
        XCTAssertEqual(CuttleContext.job(job.id).displayLabel(jobs: jobs), "Alpha \u{2014} Engineer")
        // Job not found falls back
        XCTAssertEqual(CuttleContext.job(UUID()).displayLabel(jobs: jobs), "Job")
    }

    // MARK: - CuttleMood

    func testCuttleMoodAmplitudes() {
        XCTAssertEqual(CuttleMood.idle.amplitudeFrac, 0.08)
        XCTAssertEqual(CuttleMood.thinking.amplitudeFrac, 0.12)
        XCTAssertEqual(CuttleMood.listening.amplitudeFrac, 0.10)
        XCTAssertEqual(CuttleMood.transitioning.amplitudeFrac, 0.15)
    }

    // MARK: - CuttleContext Codable

    func testCuttleContextCodableRoundTrip() throws {
        let cases: [CuttleContext] = [
            .global,
            .status(.interview),
            .status(.rejected),
            .job(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
        ]
        for context in cases {
            let data = try JSONEncoder().encode(context)
            let decoded = try JSONDecoder().decode(CuttleContext.self, from: data)
            XCTAssertEqual(decoded, context)
        }
    }

    // MARK: - CuttlePromptBuilder Edge Cases

    func testJobNotFoundFallsBackToGlobal() {
        let job = Self.jobA
        let bogusId = UUID(uuidString: "00000000-0000-0000-0000-FFFFFFFFFFFF")!
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .job(bogusId), jobs: [job], profile: UserProfile(), chatHistory: []
        )
        // Should fall back to global prompt
        XCTAssertTrue(prompt.contains("full job search dashboard"))
        XCTAssertTrue(prompt.contains("Alpha"))
    }

    func testStatusPromptForRejectedIncludesPatternHint() {
        let job = Self.jobB  // status: .rejected
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .status(.rejected), jobs: [job], profile: UserProfile(), chatHistory: []
        )
        XCTAssertTrue(prompt.contains("Rejected"))
        XCTAssertTrue(prompt.contains("Beta"))
        XCTAssertTrue(prompt.contains("patterns"))
    }

    func testStatusPromptForOfferIncludesNegotiationHint() {
        let job = JobApplication.mock(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!,
            company: "OfferCo", title: "Lead", status: .offer, salary: "$200k"
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .status(.offer), jobs: [job], profile: UserProfile(), chatHistory: []
        )
        XCTAssertTrue(prompt.contains("OfferCo"))
        XCTAssertTrue(prompt.contains("$200k"))
        XCTAssertTrue(prompt.contains("compare"))
    }

    func testGlobalPromptIncludesUpcomingInterviews() {
        let futureDate = Date().addingTimeInterval(86400 * 3)
        let job = JobApplication.mock(
            company: "InterviewCo", title: "Dev", status: .interview,
            interviews: [InterviewRound(round: 1, type: "Technical", date: futureDate)]
        )
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .global, jobs: [job], profile: UserProfile(), chatHistory: []
        )
        XCTAssertTrue(prompt.contains("Upcoming Interviews"))
        XCTAssertTrue(prompt.contains("InterviewCo"))
    }

    func testChatHistoryTruncatesLongMessages() {
        let longMessage = String(repeating: "x", count: 500)
        let history = [ChatMessage(role: .user, content: longMessage)]
        let prompt = CuttlePromptBuilder.buildPrompt(
            context: .global, jobs: [], profile: UserProfile(), chatHistory: history
        )
        // Should contain truncated version (300 chars + "...")
        XCTAssertTrue(prompt.contains("..."))
        XCTAssertFalse(prompt.contains(longMessage))
    }
}
