import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class CuttleOnboardingTests: XCTestCase {

    // MARK: - Start

    func testStartSetsActiveAndFirstStepWhenAiNotReady() async {
        let store = TestStore(initialState: CuttleOnboardingFeature.State()) {
            CuttleOnboardingFeature()
        } withDependencies: {
            $0.acpRegistryClient.fetchAgents = { [] }
        }

        await store.send(.start) {
            $0.isActive = true
            $0.currentStep = .discoverAgent
        }
        await store.receive(\.fetchRegistry) {
            $0.isLoadingAgents = true
        }
        await store.receive(\.registryLoaded) {
            $0.isLoadingAgents = false
        }
    }

    func testStartSetsActiveAndFirstStepWhenAiReady() async {
        var state = CuttleOnboardingFeature.State()
        state.aiReady = true
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.start) {
            $0.isActive = true
            $0.currentStep = .meetCuttle
        }
    }

    // MARK: - Registry

    func testFetchRegistrySuccess() async {
        let mockAgents = [
            ACPAgentEntry(
                id: "test-agent",
                name: "Test Agent",
                version: "1.0.0",
                description: "A test agent",
                authors: ["Tester"],
                distribution: ACPDistribution(npx: ACPNpx(package: "test-agent"))
            )
        ]
        let store = TestStore(initialState: CuttleOnboardingFeature.State()) {
            CuttleOnboardingFeature()
        } withDependencies: {
            $0.acpRegistryClient.fetchAgents = { mockAgents }
        }

        await store.send(.fetchRegistry) {
            $0.isLoadingAgents = true
        }
        await store.receive(\.registryLoaded) {
            $0.isLoadingAgents = false
            $0.availableAgents = mockAgents
        }
    }

    func testFetchRegistryFailure() async {
        struct TestError: LocalizedError {
            var errorDescription: String? { "Network error" }
        }
        let store = TestStore(initialState: CuttleOnboardingFeature.State()) {
            CuttleOnboardingFeature()
        } withDependencies: {
            $0.acpRegistryClient.fetchAgents = { throw TestError() }
        }

        await store.send(.fetchRegistry) {
            $0.isLoadingAgents = true
        }
        await store.receive(\.registryLoaded) {
            $0.isLoadingAgents = false
            $0.registryError = "Network error"
        }
    }

    // MARK: - Agent Selection

    func testSelectAgent() async {
        let store = TestStore(initialState: CuttleOnboardingFeature.State()) {
            CuttleOnboardingFeature()
        }

        await store.send(.selectAgent("my-agent")) {
            $0.selectedAgentId = "my-agent"
        }
    }

    func testSearchTextChanged() async {
        let store = TestStore(initialState: CuttleOnboardingFeature.State()) {
            CuttleOnboardingFeature()
        }

        await store.send(.searchTextChanged("test")) {
            $0.agentSearchText = "test"
        }
    }

    // MARK: - Connect

    func testConnectToAgentSuccess() async {
        var state = CuttleOnboardingFeature.State()
        state.availableAgents = [
            ACPAgentEntry(
                id: "test-agent",
                name: "Test Agent",
                version: "1.0.0",
                description: "A test",
                authors: [],
                distribution: ACPDistribution(npx: ACPNpx(package: "test-agent"))
            )
        ]
        state.selectedAgentId = "test-agent"

        let store = TestStore(initialState: state) {
            CuttleOnboardingFeature()
        } withDependencies: {
            $0.acpClient.connect = { _ in "Test Agent" }
        }

        await store.send(.connectToAgent) {
            $0.isConnecting = true
        }
        await store.receive(\.connectionResult) {
            $0.isConnecting = false
            $0.isConnected = true
            $0.connectedAgentName = "Test Agent"
            $0.aiReady = true
        }
        await store.receive(\.delegate.agentConnected)
    }

    func testConnectToAgentFailure() async {
        struct TestError: LocalizedError {
            var errorDescription: String? { "Connection failed" }
        }
        var state = CuttleOnboardingFeature.State()
        state.availableAgents = [
            ACPAgentEntry(
                id: "test-agent",
                name: "Test Agent",
                version: "1.0.0",
                description: "A test",
                authors: [],
                distribution: ACPDistribution(npx: ACPNpx(package: "test-agent"))
            )
        ]
        state.selectedAgentId = "test-agent"

        let store = TestStore(initialState: state) {
            CuttleOnboardingFeature()
        } withDependencies: {
            $0.acpClient.connect = { _ in throw TestError() }
        }

        await store.send(.connectToAgent) {
            $0.isConnecting = true
        }
        await store.receive(\.connectionResult) {
            $0.isConnecting = false
            $0.connectionError = "Connection failed"
        }
    }

    func testRetryConnection() async {
        var state = CuttleOnboardingFeature.State()
        state.availableAgents = [
            ACPAgentEntry(
                id: "test-agent",
                name: "Test Agent",
                version: "1.0.0",
                description: "A test",
                authors: [],
                distribution: ACPDistribution(npx: ACPNpx(package: "test-agent"))
            )
        ]
        state.selectedAgentId = "test-agent"
        state.connectionError = "Previous error"

        let store = TestStore(initialState: state) {
            CuttleOnboardingFeature()
        } withDependencies: {
            $0.acpClient.connect = { _ in "Test Agent" }
        }

        await store.send(.retryConnection)
        await store.receive(\.connectToAgent) {
            $0.isConnecting = true
            $0.connectionError = nil
        }
        await store.receive(\.connectionResult) {
            $0.isConnecting = false
            $0.isConnected = true
            $0.connectedAgentName = "Test Agent"
            $0.aiReady = true
        }
        await store.receive(\.delegate.agentConnected)
    }

    // MARK: - Skip Agent Setup

    func testSkipAgentSetup() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.currentStep = .discoverAgent
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.skipAgentSetup) {
            $0.currentStep = .meetCuttle
        }
    }

    // MARK: - Next Step

    func testNextStepAdvances() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.aiReady = true
        state.currentStep = .meetCuttle
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.nextStep) {
            $0.currentStep = .expandCollapse
        }
    }

    func testNextStepToChatBasicsExpandsCuttle() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.aiReady = true
        state.currentStep = .expandCollapse
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.nextStep) {
            $0.currentStep = .chatBasics
        }
        await store.receive(\.delegate.expandCuttle)
    }

    func testNextStepFromChatBasicsCollapsesCuttle() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.aiReady = true
        state.currentStep = .chatBasics
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.nextStep) {
            $0.currentStep = .dragToDock
        }
        await store.receive(\.delegate.collapseCuttle)
    }

    func testNextStepOnLastStepFinishes() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.aiReady = true
        state.currentStep = .resize
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.nextStep)
        await store.receive(\.finish) {
            $0.isActive = false
        }
        await store.receive(\.delegate.completed)
    }

    // MARK: - Previous Step

    func testPreviousStepGoesBack() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.aiReady = true
        state.currentStep = .carryOrFresh
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.previousStep) {
            $0.currentStep = .dragToDock
        }
    }

    func testPreviousStepAtFirstDoesNothing() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.aiReady = true
        state.currentStep = .meetCuttle
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.previousStep)
    }

    func testPreviousStepFromChatBasicsCollapsesCuttle() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.aiReady = true
        state.currentStep = .chatBasics
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.previousStep) {
            $0.currentStep = .expandCollapse
        }
        await store.receive(\.delegate.collapseCuttle)
    }

    // MARK: - Skip All

    func testSkipAllDeactivatesAndSendsDelegate() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.currentStep = .dragToDock
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.skipAll) {
            $0.isActive = false
        }
        await store.receive(\.delegate.dismissed)
    }

    // MARK: - Finish

    func testFinishDeactivatesAndSendsDelegate() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.finish) {
            $0.isActive = false
        }
        await store.receive(\.delegate.completed)
    }

    // MARK: - Step Filtering

    func testDiscoverAndConnectIncludedWhenAiNotReady() {
        var state = CuttleOnboardingFeature.State()
        state.aiReady = false
        XCTAssertTrue(state.steps.contains(.discoverAgent))
        XCTAssertTrue(state.steps.contains(.connectAgent))
    }

    func testDiscoverAndConnectExcludedWhenAiReady() {
        var state = CuttleOnboardingFeature.State()
        state.aiReady = true
        XCTAssertFalse(state.steps.contains(.discoverAgent))
        XCTAssertFalse(state.steps.contains(.connectAgent))
    }

    func testStepCountWithAiReady() {
        var state = CuttleOnboardingFeature.State()
        state.aiReady = true
        XCTAssertEqual(state.steps.count, 6)

        state.aiReady = false
        XCTAssertEqual(state.steps.count, 8)
    }

    // MARK: - State Properties

    func testIsFirstStep() {
        var state = CuttleOnboardingFeature.State()
        state.aiReady = true
        state.currentStep = .meetCuttle
        XCTAssertTrue(state.isFirstStep)

        state.currentStep = .expandCollapse
        XCTAssertFalse(state.isFirstStep)
    }

    func testIsLastStep() {
        var state = CuttleOnboardingFeature.State()
        state.aiReady = true
        state.currentStep = .resize
        XCTAssertTrue(state.isLastStep)

        state.currentStep = .meetCuttle
        XCTAssertFalse(state.isLastStep)
    }

    // MARK: - Filtered Agents

    func testFilteredAgentsWithSearch() {
        var state = CuttleOnboardingFeature.State()
        state.availableAgents = [
            ACPAgentEntry(
                id: "a1",
                name: "Alpha Agent",
                version: "1.0.0",
                description: "First agent",
                authors: [],
                distribution: ACPDistribution()
            ),
            ACPAgentEntry(
                id: "b1",
                name: "Beta Agent",
                version: "1.0.0",
                description: "Second agent",
                authors: [],
                distribution: ACPDistribution()
            ),
        ]
        state.agentSearchText = "alpha"
        XCTAssertEqual(state.filteredAgents.count, 1)
        XCTAssertEqual(state.filteredAgents.first?.id, "a1")
    }

    func testSelectedAgentComputed() {
        var state = CuttleOnboardingFeature.State()
        let agent = ACPAgentEntry(
            id: "test",
            name: "Test",
            version: "1.0.0",
            description: "Test",
            authors: [],
            distribution: ACPDistribution()
        )
        state.availableAgents = [agent]
        state.selectedAgentId = "test"
        XCTAssertEqual(state.selectedAgent, agent)

        state.selectedAgentId = "nonexistent"
        XCTAssertNil(state.selectedAgent)
    }
}
