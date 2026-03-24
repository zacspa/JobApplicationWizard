import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class AppFeatureTests: XCTestCase {

    // MARK: - onAppear

    func testOnAppearLoadsJobsSettingsAndAPIKey() async {
        let jobs = [JobApplication.mock()]
        let settings: AppSettings = {
            var s = AppSettings()
            s.userProfile.name = "Test"
            return s
        }()

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.loadJobs = { jobs }
            $0.persistenceClient.loadSettings = { settings }
            $0.keychainClient.loadAPIKey = { "sk-test-key" }
            $0.keychainClient.saveAPIKey = { _ in }
            $0.acpRegistryClient = ACPRegistryClient(fetchAgents: { [] })
        }

        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.jobsLoaded) {
            $0.jobs = IdentifiedArray(uniqueElements: jobs)
        }
        await store.receive(\.settingsLoaded) {
            $0.settings = settings
            $0.viewMode = settings.defaultViewMode
            $0.$acpConnection.withLock { $0.aiProvider = settings.aiProvider }
        }
        await store.receive(\.saveSettingsKey) {
            $0.claudeAPIKey = "sk-test-key"
        }
    }

    func testEmptyJobsTriggersOnboarding() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.loadJobs = { [] }
            $0.persistenceClient.loadSettings = { AppSettings() }
            $0.keychainClient.loadAPIKey = { "" }
            $0.keychainClient.saveAPIKey = { _ in }
            $0.acpRegistryClient = ACPRegistryClient(fetchAgents: { [] })
        }

        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.jobsLoaded) {
            $0.jobs = []
            $0.showOnboarding = true
        }
        await store.receive(\.settingsLoaded)
        await store.receive(\.saveSettingsKey)
    }

    // MARK: - Search & Filter

    func testSearchQueryChanged() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.searchQueryChanged("test")) {
            $0.searchQuery = "test"
        }
    }

    func testFilterStatusChanged() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.filterStatusChanged(.applied)) {
            $0.filterStatus = .applied
        }
        await store.send(.filterStatusChanged(nil)) {
            $0.filterStatus = nil
        }
    }

    func testFilteredJobsRespectsSearchAndStatus() {
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [
            .mock(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, company: "Alpha", status: .applied),
            .mock(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, company: "Beta", status: .wishlist),
            .mock(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, company: "Gamma", status: .applied),
        ])

        // Filter by status
        state.filterStatus = .applied
        XCTAssertEqual(state.filteredJobs.count, 2)

        // Filter by search
        state.filterStatus = nil
        state.searchQuery = "Beta"
        XCTAssertEqual(state.filteredJobs.count, 1)
        XCTAssertEqual(state.filteredJobs.first?.company, "Beta")
    }

    // MARK: - selectJob

    func testSelectJobCreatesJobDetailState() async {
        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.selectJob(job.id)) {
            $0.selectedJobID = job.id
            $0.jobDetail = JobDetailFeature.State(job: job)
        }
    }

    func testSelectNilClearsJobDetail() async {
        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])
        state.selectedJobID = job.id
        state.jobDetail = JobDetailFeature.State(job: job)

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.selectJob(nil)) {
            $0.selectedJobID = nil
            $0.jobDetail = nil
        }
    }

    // MARK: - moveJob

    func testMoveJobUpdatesStatusAndSaves() async {
        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
        }

        store.exhaustivity = .off
        await store.send(.moveJob(job.id, .applied))

        // Verify status and dateApplied were set
        XCTAssertEqual(store.state.jobs[id: job.id]?.status, .applied)
        XCTAssertNotNil(store.state.jobs[id: job.id]?.dateApplied)
    }

    func testMoveJobSyncsToJobDetail() async {
        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])
        state.selectedJobID = job.id
        state.jobDetail = JobDetailFeature.State(job: job)

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
        }

        store.exhaustivity = .off
        await store.send(.moveJob(job.id, .interview))

        XCTAssertEqual(store.state.jobs[id: job.id]?.status, .interview)
        XCTAssertEqual(store.state.jobDetail?.job.status, .interview)
    }

    // MARK: - deleteJob

    func testDeleteJobRemovesAndClearsSelection() async {
        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])
        state.selectedJobID = job.id
        state.jobDetail = JobDetailFeature.State(job: job)

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
        }

        store.exhaustivity = .off
        await store.send(.deleteJob(job.id))

        XCTAssertTrue(store.state.jobs.isEmpty)
        XCTAssertNil(store.state.selectedJobID)
        XCTAssertNil(store.state.jobDetail)
    }

    // MARK: - toggleFavorite

    func testToggleFavorite() async {
        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
        }

        store.exhaustivity = .off
        await store.send(.toggleFavorite(job.id))

        XCTAssertEqual(store.state.jobs[id: job.id]?.isFavorite, true)
    }

    // MARK: - Child Delegation: AddJob

    func testAddJobSaveDelegateSavesAndSelects() async {
        let newJob = JobApplication.mock()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
        }

        store.exhaustivity = .off
        await store.send(.addJob(.delegate(.save(newJob))))

        XCTAssertEqual(store.state.jobs[id: newJob.id]?.company, newJob.company)
        XCTAssertEqual(store.state.selectedJobID, newJob.id)
        XCTAssertNotNil(store.state.jobDetail)
    }

    func testAddJobCancelDelegateResetsState() async {
        var state = AppFeature.State()
        state.addJob.company = "Partial"

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.addJob(.delegate(.cancel))) {
            $0.addJob = AddJobFeature.State()
        }
    }

    // MARK: - Child Delegation: JobDetail

    func testJobDetailUpdatedDelegateSyncsBack() async {
        var job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])
        state.selectedJobID = job.id
        state.jobDetail = JobDetailFeature.State(job: job)

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
        }

        store.exhaustivity = .off
        job.company = "Updated Corp"
        await store.send(.jobDetail(.delegate(.jobUpdated(job))))

        XCTAssertEqual(store.state.jobs[id: job.id]?.company, "Updated Corp")
    }

    func testJobDetailDeletedDelegateRemovesJob() async {
        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])
        state.selectedJobID = job.id
        state.jobDetail = JobDetailFeature.State(job: job)

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
            $0.historyClient.record = { _ in }
        }

        store.exhaustivity = .off
        await store.send(.jobDetail(.delegate(.jobDeleted(job.id))))

        XCTAssertTrue(store.state.jobs.isEmpty)
        XCTAssertNil(store.state.selectedJobID)
        XCTAssertNil(store.state.jobDetail)
    }

    // MARK: - importCSVResult

    func testImportCSVResultMergesAndSkipsExisting() async {
        let existing = JobApplication.mock(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            company: "Existing"
        )
        let newJob = JobApplication.mock(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            company: "Imported"
        )
        let duplicate = JobApplication.mock(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            company: "Should Be Skipped"
        )

        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [existing])
        state.filterStatus = .applied

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
        }

        await store.send(.importCSVResult([duplicate, newJob])) {
            $0.jobs.append(newJob)
            $0.filterStatus = nil  // cleared to show imported jobs
            $0.cuttle.jobs = Array($0.jobs)
        }

        // Verify the existing job was NOT overwritten
        XCTAssertEqual(store.state.jobs[id: existing.id]?.company, "Existing")
    }

    // MARK: - saveSettingsKey

    func testSaveSettingsKeySyncsToJobDetail() async {
        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])
        state.selectedJobID = job.id
        state.jobDetail = JobDetailFeature.State(job: job)

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.keychainClient.saveAPIKey = { _ in }
        }

        await store.send(.saveSettingsKey("new-key")) {
            $0.claudeAPIKey = "new-key"
            $0.jobDetail?.apiKey = "new-key"
            $0.cuttle.apiKey = "new-key"
        }
    }

    // MARK: - saveProfile

    func testSaveProfileUpdatesSettingsAndSyncsToJobDetail() async {
        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])
        state.selectedJobID = job.id
        state.jobDetail = JobDetailFeature.State(job: job)

        var profile = UserProfile()
        profile.name = "Updated Name"

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveSettings = { _ in }
        }

        await store.send(.saveProfile(profile)) {
            $0.settings.userProfile = profile
            $0.jobDetail?.userProfile = profile
            $0.cuttle.userProfile = profile
        }
    }

    // MARK: - resetAllData

    func testResetAllDataClearsEverything() async {
        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])
        state.selectedJobID = job.id
        state.jobDetail = JobDetailFeature.State(job: job)

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in }
        }

        await store.send(.resetAllData) {
            $0.jobs = []
            $0.selectedJobID = nil
            $0.jobDetail = nil
            $0.showOnboarding = true
        }
    }

    // MARK: - Error Handling (Phase 1)

    func testJobsLoadFailureShowsSaveError() async {
        struct LoadError: Error, LocalizedError {
            var errorDescription: String? { "Corrupt JSON" }
        }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.loadJobs = { throw LoadError() }
            $0.persistenceClient.loadSettings = { AppSettings() }
            $0.keychainClient.loadAPIKey = { "" }
            $0.keychainClient.saveAPIKey = { _ in }
            $0.acpRegistryClient = ACPRegistryClient(fetchAgents: { [] })
        }

        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.jobsLoaded) {
            $0.saveError = "Failed to load jobs: Corrupt JSON. Your data file may be corrupted; check jobs.json or jobs.backup.json in Application Support."
        }
        await store.receive(\.settingsLoaded)
        await store.receive(\.saveSettingsKey)
    }

    func testSaveFailureSurfacesError() async {
        struct DiskFullError: Error, LocalizedError {
            var errorDescription: String? { "Disk full" }
        }

        let job = JobApplication.mock()
        var state = AppFeature.State()
        state.jobs = IdentifiedArray(uniqueElements: [job])

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.saveJobs = { _ in throw DiskFullError() }
            $0.historyClient.record = { _ in }
        }

        store.exhaustivity = .off
        await store.send(.toggleFavorite(job.id))
        await store.receive(\.saveFailed)

        XCTAssertEqual(store.state.saveError, "Failed to save jobs: Disk full")
    }

    // MARK: - ACP Disconnect

    func testDisconnectACPAgentClearsConnectionState() async {
        let state = AppFeature.State()
        state.$acpConnection.withLock {
            $0.isConnected = true
            $0.connectedAgentName = "test-agent"
        }

        let disconnectCalled = LockIsolated(false)
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.acpClient = ACPClient(
                connect: { _ in "" },
                disconnect: { disconnectCalled.setValue(true) },
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

        XCTAssertTrue(disconnectCalled.value, "acpClient.disconnect() should be called")
    }

    func testDismissSaveError() async {
        var state = AppFeature.State()
        state.saveError = "Some error"

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.dismissSaveError) {
            $0.saveError = nil
        }
    }
}
