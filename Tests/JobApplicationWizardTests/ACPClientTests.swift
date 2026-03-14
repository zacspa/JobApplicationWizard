import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class ACPClientTests: XCTestCase {

    // MARK: - Registry Decoding

    func testACPAgentEntryDecoding() throws {
        let json = """
        {
            "id": "goose",
            "name": "Goose",
            "version": "1.2.0",
            "description": "An AI agent by Block",
            "authors": ["Block"],
            "repository": "https://github.com/block/goose",
            "license": "Apache-2.0",
            "distribution": {
                "npx": { "package": "@anthropic/goose", "args": ["--acp"] },
                "binary": {
                    "darwin-aarch64": { "archive": "https://example.com/goose.zip", "cmd": "./goose" }
                }
            }
        }
        """.data(using: .utf8)!

        let entry = try JSONDecoder().decode(ACPAgentEntry.self, from: json)
        XCTAssertEqual(entry.id, "goose")
        XCTAssertEqual(entry.name, "Goose")
        XCTAssertEqual(entry.version, "1.2.0")
        XCTAssertEqual(entry.description, "An AI agent by Block")
        XCTAssertEqual(entry.authors, ["Block"])
        XCTAssertEqual(entry.distribution.npx?.package, "@anthropic/goose")
        XCTAssertEqual(entry.distribution.npx?.args, ["--acp"])
        XCTAssertEqual(entry.distribution.binary?["darwin-aarch64"]?.cmd, "./goose")
        XCTAssertEqual(entry.repository, "https://github.com/block/goose")
    }

    func testACPAgentEntryId() {
        let entry = ACPAgentEntry(
            id: "test-agent",
            name: "Test Agent",
            version: "2.0.0",
            description: "Test",
            authors: [],
            distribution: ACPDistribution()
        )
        XCTAssertEqual(entry.id, "test-agent")
    }

    func testACPAgentEntryDecodingMinimal() throws {
        let json = """
        {
            "id": "minimal",
            "name": "Minimal",
            "version": "0.1.0",
            "distribution": {}
        }
        """.data(using: .utf8)!

        let entry = try JSONDecoder().decode(ACPAgentEntry.self, from: json)
        XCTAssertEqual(entry.id, "minimal")
        XCTAssertEqual(entry.name, "Minimal")
        XCTAssertEqual(entry.description, "")  // defaults to empty
        XCTAssertNil(entry.distribution.binary)
        XCTAssertNil(entry.distribution.npx)
        XCTAssertNil(entry.distribution.uvx)
    }

    // MARK: - AIProvider Model

    func testAIProviderCodable() throws {
        let settings = AppSettings()
        XCTAssertEqual(settings.aiProvider, .acpAgent)
        XCTAssertNil(settings.selectedACPAgentId)

        // Encode and decode
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.aiProvider, .acpAgent)
    }

    func testAIProviderACPCodable() throws {
        var settings = AppSettings()
        settings.aiProvider = .acpAgent
        settings.selectedACPAgentId = "goose-1.0.0"

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.aiProvider, .acpAgent)
        XCTAssertEqual(decoded.selectedACPAgentId, "goose-1.0.0")
    }

    func testAIProviderBackwardCompat() throws {
        let json = """
        {
            "defaultViewMode": "Kanban"
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(settings.aiProvider, .acpAgent)
        XCTAssertNil(settings.selectedACPAgentId)
    }

    // MARK: - ACPConnectionState

    func testACPConnectionStateDefaults() {
        let conn = ACPConnectionState()
        XCTAssertEqual(conn.aiProvider, .acpAgent)
        XCTAssertFalse(conn.isConnecting)
        XCTAssertFalse(conn.isConnected)
        XCTAssertNil(conn.connectedAgentName)
        XCTAssertNil(conn.error)
    }

    // MARK: - JobDetailFeature State Initialization

    func testJobDetailStateInitDefaultsToACPAgent() {
        let state = JobDetailFeature.State(job: .mock())
        // acpConnection is shared state — default is .acpAgent, not connected
        XCTAssertEqual(state.acpConnection.aiProvider, .acpAgent)
        XCTAssertFalse(state.acpConnection.isConnected)
        XCTAssertNil(state.acpConnection.connectedAgentName)
    }

    // MARK: - AppFeature Provider Switching

    func testAIProviderChangedUpdatesSetting() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveSettings = { _ in }
            $0.acpRegistryClient = ACPRegistryClient(
                fetchAgents: { [] }
            )
        }

        store.exhaustivity = .off

        await store.send(.aiProviderChanged(.acpAgent)) {
            $0.$acpConnection.withLock { $0.aiProvider = .acpAgent }
            $0.settings.aiProvider = .acpAgent
        }
    }

    func testFetchACPRegistrySuccess() async {
        let mockAgents = [
            ACPAgentEntry(
                id: "goose",
                name: "Goose",
                version: "1.0.0",
                description: "AI agent",
                authors: ["Block"],
                distribution: ACPDistribution(npx: ACPNpx(package: "goose"))
            )
        ]

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.acpRegistryClient = ACPRegistryClient(
                fetchAgents: { mockAgents }
            )
        }

        store.exhaustivity = .off

        await store.send(.fetchACPRegistry) {
            $0.isLoadingAgents = true
        }

        await store.receive(\.acpRegistryLoaded) {
            $0.isLoadingAgents = false
            $0.availableACPAgents = mockAgents
        }
    }

    func testSelectACPAgent() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveSettings = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.selectACPAgent("goose")) {
            $0.settings.selectedACPAgentId = "goose"
        }
    }

    func testFetchACPRegistryFailure() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.acpRegistryClient = ACPRegistryClient(
                fetchAgents: { throw ACPRegistryError.fetchFailed }
            )
        }

        store.exhaustivity = .off

        await store.send(.fetchACPRegistry) {
            $0.isLoadingAgents = true
        }

        await store.receive(\.acpRegistryLoaded) {
            $0.isLoadingAgents = false
            $0.$acpConnection.withLock {
                $0.error = ACPRegistryError.fetchFailed.localizedDescription
            }
        }
    }

    func testConnectACPAgentSuccess() async {
        let mockAgent = ACPAgentEntry(
            id: "claude-acp",
            name: "Claude Agent",
            version: "1.0.0",
            description: "Test",
            authors: [],
            distribution: ACPDistribution(npx: ACPNpx(package: "test"))
        )

        var initialState = AppFeature.State()
        initialState.availableACPAgents = [mockAgent]
        initialState.settings.selectedACPAgentId = "claude-acp"

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.acpClient = ACPClient(
                connect: { _ in "Claude Agent" },
                disconnect: {},
                sendPrompt: { _, _ in ("", .zero) },
                onUnexpectedDisconnect: { AsyncStream { $0.finish() } }
            )
        }

        store.exhaustivity = .off

        await store.send(.connectACPAgent) {
            $0.$acpConnection.withLock { $0.isConnecting = true }
        }

        await store.receive(\.acpConnected) {
            $0.$acpConnection.withLock {
                $0.isConnecting = false
                $0.isConnected = true
                $0.connectedAgentName = "Claude Agent"
            }
        }
    }

    func testConnectACPAgentFailure() async {
        let mockAgent = ACPAgentEntry(
            id: "bad-agent",
            name: "Bad Agent",
            version: "1.0.0",
            description: "Test",
            authors: [],
            distribution: ACPDistribution(npx: ACPNpx(package: "nonexistent"))
        )

        var initialState = AppFeature.State()
        initialState.availableACPAgents = [mockAgent]
        initialState.settings.selectedACPAgentId = "bad-agent"

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.acpClient = ACPClient(
                connect: { _ in throw ACPClientError.launchFailed("Bad Agent", "exit code 127") },
                disconnect: {},
                sendPrompt: { _, _ in ("", .zero) },
                onUnexpectedDisconnect: { AsyncStream { $0.finish() } }
            )
        }

        store.exhaustivity = .off

        await store.send(.connectACPAgent) {
            $0.$acpConnection.withLock { $0.isConnecting = true }
        }

        await store.receive(\.acpConnected) {
            $0.$acpConnection.withLock {
                $0.isConnecting = false
                $0.isConnected = false
                $0.error = "Failed to connect to 'Bad Agent': exit code 127"
            }
        }
    }

    func testConnectACPAgentNoSelection() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        store.exhaustivity = .off

        await store.send(.connectACPAgent) {
            $0.$acpConnection.withLock { $0.error = "No agent selected." }
        }
    }

    func testAutoConnectOnRegistryLoad() async {
        let mockAgent = ACPAgentEntry(
            id: "claude-acp",
            name: "Claude Agent",
            version: "1.0.0",
            description: "Test",
            authors: [],
            distribution: ACPDistribution(npx: ACPNpx(package: "test"))
        )

        var initialState = AppFeature.State()
        initialState.settings.selectedACPAgentId = "claude-acp"

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.acpRegistryClient = ACPRegistryClient(fetchAgents: { [mockAgent] })
            $0.acpClient = ACPClient(
                connect: { _ in "Claude Agent" },
                disconnect: {},
                sendPrompt: { _, _ in ("", .zero) },
                onUnexpectedDisconnect: { AsyncStream { $0.finish() } }
            )
        }

        store.exhaustivity = .off

        await store.send(.fetchACPRegistry)

        // Should auto-trigger connectACPAgent after registry loads
        await store.receive(\.acpRegistryLoaded)
        await store.receive(\.connectACPAgent)
        await store.receive(\.acpConnected)
    }

    func testSwitchToClaudeAPIProvider() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveSettings = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.aiProviderChanged(.claudeAPI)) {
            $0.$acpConnection.withLock { $0.aiProvider = .claudeAPI }
            $0.settings.aiProvider = .claudeAPI
        }
    }

    // MARK: - Disconnect

    func testDisconnectACPAgent() async {
        var initialState = AppFeature.State()
        initialState.$acpConnection.withLock {
            $0.isConnected = true
            $0.connectedAgentName = "goose"
        }

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.acpClient = ACPClient(
                connect: { _ in "" },
                disconnect: {},
                sendPrompt: { _, _ in ("", .zero) },
                onUnexpectedDisconnect: { AsyncStream { $0.finish() } }
            )
        }

        store.exhaustivity = .off

        await store.send(.disconnectACPAgent)

        await store.receive(\.acpDisconnected) {
            $0.$acpConnection.withLock {
                $0.isConnected = false
                $0.connectedAgentName = nil
            }
        }
    }
}
