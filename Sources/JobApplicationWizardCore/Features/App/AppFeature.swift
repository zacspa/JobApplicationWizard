import ComposableArchitecture
import Foundation

public enum ViewMode: String, Codable, CaseIterable, Equatable {
    case kanban = "Kanban"
    case list = "List"

    public var icon: String {
        switch self {
        case .kanban: return "square.grid.3x2"
        case .list:   return "list.bullet"
        }
    }
}

@Reducer
public struct AppFeature {
    private enum CancelID { case acpCrashMonitor, save, saveSettings }

    @ObservableState
    public struct State: Equatable {
        public var jobs: IdentifiedArrayOf<JobApplication> = []
        public var selectedJobID: UUID? = nil
        public var searchQuery: String = ""
        public var filterStatus: JobStatus? = nil
        public var viewMode: ViewMode = .kanban
        public var showOnboarding: Bool = false
        public var showProfile: Bool = false
        public var settings: AppSettings = AppSettings()
        public var claudeAPIKey: String = ""   // runtime mirror of Keychain value; never persisted to disk
        public var addJob: AddJobFeature.State = AddJobFeature.State()
        public var jobDetail: JobDetailFeature.State? = nil
        public var saveError: String? = nil
        public var showImportAllConfirm: Bool = false
        public var pendingImportAll: AppDataExport? = nil

        // ACP state — connection state is shared with JobDetailFeature via @Shared
        @Shared(.inMemory("acpConnection")) public var acpConnection = ACPConnectionState()
        public var availableACPAgents: [ACPAgentEntry] = []
        public var isLoadingAgents: Bool = false

        public var filteredJobs: [JobApplication] {
            jobs.filter { job in
                let matchesSearch = searchQuery.isEmpty ||
                    job.company.localizedCaseInsensitiveContains(searchQuery) ||
                    job.title.localizedCaseInsensitiveContains(searchQuery) ||
                    job.location.localizedCaseInsensitiveContains(searchQuery)
                let matchesStatus = filterStatus == nil || job.status == filterStatus
                return matchesSearch && matchesStatus
            }
        }

        public var stats: (total: Int, active: Int, offers: Int, interviews: Int) {
            let active = jobs.filter { ![.rejected, .withdrawn, .offer].contains($0.status) }.count
            let offers = jobs.filter { $0.status == .offer }.count
            let interviews = jobs.filter { $0.status == .interview }.count
            return (jobs.count, active, offers, interviews)
        }

        public init() {}
    }

    public enum Action {
        case onAppear
        case jobsLoaded(Result<[JobApplication], Error>)
        case settingsLoaded(Result<AppSettings, Error>)
        case searchQueryChanged(String)
        case saveFailed(String)
        case dismissSaveError
        case filterStatusChanged(JobStatus?)
        case viewModeChanged(ViewMode)
        case selectJob(UUID?)
        case moveJob(UUID, JobStatus)
        case deleteJob(UUID)
        case toggleFavorite(UUID)
        case prepareAddJob
        case addJob(AddJobFeature.Action)
        case jobDetail(JobDetailFeature.Action)
        case exportCSV
        case importCSV
        case importCSVResult([JobApplication])
        case dismissOnboarding
        case saveSettingsKey(String)
        case showProfileTapped
        case dismissProfile
        case saveProfile(UserProfile)
        case defaultViewModeChanged(ViewMode)
        case resetAllData
        case exportAll
        case importAll
        case importAllLoaded(Result<AppDataExport, Error>)
        case confirmImportAll
        case cancelImportAll
        // ACP
        case aiProviderChanged(AIProvider)
        case fetchACPRegistry
        case acpRegistryLoaded(Result<[ACPAgentEntry], Error>)
        case selectACPAgent(String)
        case connectACPAgent
        case acpConnected(Result<String, Error>)
        case disconnectACPAgent
        case acpDisconnected
        case acpProcessCrashed
    }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.acpClient) var acpClient
    @Dependency(\.acpRegistryClient) var acpRegistry

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.addJob, action: \.addJob) { AddJobFeature() }
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    async let jobs = Result { try await persistence.loadJobs() }
                    async let settings = Result { try await persistence.loadSettings() }
                    let apiKey = keychain.loadAPIKey()
                    await send(.jobsLoaded(await jobs))
                    await send(.settingsLoaded(await settings))
                    await send(.saveSettingsKey(apiKey))
                }

            case .jobsLoaded(.success(let jobs)):
                state.jobs = IdentifiedArray(uniqueElements: jobs)
                if state.jobs.isEmpty {
                    state.showOnboarding = true
                }
                return .none

            case .jobsLoaded(.failure(let error)):
                // Decode failure on an existing file; do NOT overwrite with []
                state.saveError = "Failed to load jobs: \(error.localizedDescription). Your data file may be corrupted; check jobs.json or jobs.backup.json in Application Support."
                return .none

            case .settingsLoaded(.success(let settings)):
                state.settings = settings
                state.viewMode = settings.defaultViewMode
                state.$acpConnection.withLock { $0.aiProvider = settings.aiProvider }
                if settings.aiProvider == .acpAgent {
                    return .send(.fetchACPRegistry)
                }
                return .none

            case .settingsLoaded(.failure):
                // Settings decode failure is non-critical; use defaults
                state.settings = AppSettings()
                state.viewMode = state.settings.defaultViewMode
                state.$acpConnection.withLock { $0.aiProvider = state.settings.aiProvider }
                if state.settings.aiProvider == .acpAgent {
                    return .send(.fetchACPRegistry)
                }
                return .none

            case .saveFailed(let message):
                state.saveError = message
                return .none

            case .dismissSaveError:
                state.saveError = nil
                return .none

            case .searchQueryChanged(let q):
                state.searchQuery = q
                return .none

            case .filterStatusChanged(let status):
                state.filterStatus = status
                return .none

            case .viewModeChanged(let mode):
                state.viewMode = mode
                return .none

            case .selectJob(let id):
                state.selectedJobID = id
                if let id, let job = state.jobs[id: id] {
                    let previousTab = state.jobDetail?.selectedTab
                    let previousAIPanelOpen = state.jobDetail?.aiPanelOpen ?? false
                    var detail = JobDetailFeature.State(
                        job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                    )
                    if let previousTab { detail.selectedTab = previousTab }
                    detail.aiPanelOpen = previousAIPanelOpen
                    state.jobDetail = detail
                } else {
                    state.jobDetail = nil
                }
                return .none

            case .moveJob(let id, let status):
                guard var job = state.jobs[id: id] else { return .none }
                job.status = status
                if status == .applied && job.dateApplied == nil {
                    job.dateApplied = Date()
                }
                state.jobs[id: id] = job
                if state.jobDetail?.job.id == id {
                    state.jobDetail?.job = job
                }
                return saveJobs(state.jobs)

            case .deleteJob(let id):
                state.jobs.remove(id: id)
                if state.selectedJobID == id {
                    state.selectedJobID = nil
                    state.jobDetail = nil
                }
                return saveJobs(state.jobs)

            case .toggleFavorite(let id):
                state.jobs[id: id]?.isFavorite.toggle()
                return saveJobs(state.jobs)

            case .prepareAddJob:
                state.addJob = AddJobFeature.State()
                return .none

            case .addJob(.delegate(.save(let job))):
                state.jobs.append(job)
                state.selectedJobID = job.id
                state.jobDetail = JobDetailFeature.State(
                    job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                )
                state.addJob = AddJobFeature.State()
                return saveJobs(state.jobs)

            case .addJob(.delegate(.cancel)):
                state.addJob = AddJobFeature.State()
                return .none

            case .addJob:
                return .none

            case .jobDetail(.delegate(.jobUpdated(let job))):
                state.jobs[id: job.id] = job
                return saveJobs(state.jobs)

            case .jobDetail(.delegate(.jobDeleted(let id))):
                state.jobs.remove(id: id)
                state.selectedJobID = nil
                state.jobDetail = nil
                return saveJobs(state.jobs)

            case .jobDetail:
                return .none

            case .exportCSV:
                let csv = persistence.exportCSV(Array(state.jobs))
                return .run { _ in
                    await persistence.showCSVSavePanel(csv)
                }

            case .importCSV:
                return .run { send in
                    guard let text = await persistence.showCSVOpenPanel() else { return }
                    let jobs = persistence.importCSV(text)
                    await send(.importCSVResult(jobs))
                }

            case .importCSVResult(let imported):
                // Merge: skip any job whose ID already exists
                let existingIDs = Set(state.jobs.ids)
                let newJobs = imported.filter { !existingIDs.contains($0.id) }
                for job in newJobs { state.jobs.append(job) }
                if !newJobs.isEmpty { state.filterStatus = nil }  // show all so imported jobs are visible
                return saveJobs(state.jobs)

            case .dismissOnboarding:
                state.showOnboarding = false
                return .none

            case .saveSettingsKey(let key):
                state.claudeAPIKey = key
                state.jobDetail?.apiKey = key
                return .run { _ in
                    keychain.saveAPIKey(key)
                }

            case .showProfileTapped:
                state.showProfile = true
                return .none

            case .dismissProfile:
                state.showProfile = false
                return .none

            case .saveProfile(let profile):
                state.settings.userProfile = profile
                state.jobDetail?.userProfile = profile
                return saveSettings(state.settings)

            case .defaultViewModeChanged(let mode):
                state.viewMode = mode
                state.settings.defaultViewMode = mode
                return saveSettings(state.settings)

            case .resetAllData:
                state.jobs = []
                state.selectedJobID = nil
                state.jobDetail = nil
                state.showOnboarding = true
                return saveJobs(state.jobs)

            case .exportAll:
                let data = persistence.exportAllData(Array(state.jobs), state.settings)
                return .run { _ in
                    await persistence.showJSONSavePanel(data)
                }

            case .importAll:
                return .run { send in
                    guard let data = await persistence.showJSONOpenPanel() else { return }
                    await send(.importAllLoaded(Result { try persistence.importAllData(data) }))
                }

            case .importAllLoaded(.success(let export)):
                state.pendingImportAll = export
                state.showImportAllConfirm = true
                return .none

            case .importAllLoaded(.failure(let error)):
                state.saveError = "Failed to read backup: \(error.localizedDescription)"
                return .none

            case .confirmImportAll:
                guard let export = state.pendingImportAll else { return .none }
                state.jobs = IdentifiedArray(uniqueElements: export.jobs)
                state.settings = export.settings
                state.viewMode = export.settings.defaultViewMode
                state.$acpConnection.withLock { $0.aiProvider = export.settings.aiProvider }
                state.selectedJobID = nil
                state.jobDetail = nil
                state.pendingImportAll = nil
                state.showImportAllConfirm = false
                return .merge(
                    saveJobs(state.jobs),
                    saveSettings(state.settings)
                )

            case .cancelImportAll:
                state.pendingImportAll = nil
                state.showImportAllConfirm = false
                return .none

            // MARK: - ACP Actions

            case .aiProviderChanged(let provider):
                state.$acpConnection.withLock {
                    $0.aiProvider = provider
                    $0.error = nil
                }
                state.settings.aiProvider = provider
                var effects: [Effect<Action>] = [saveSettings(state.settings)]
                if provider == .acpAgent && state.availableACPAgents.isEmpty {
                    effects.append(.send(.fetchACPRegistry))
                }
                return .merge(effects)

            case .fetchACPRegistry:
                state.isLoadingAgents = true
                state.$acpConnection.withLock { $0.error = nil }
                return .run { send in
                    await send(.acpRegistryLoaded(Result { try await acpRegistry.fetchAgents() }))
                }

            case .acpRegistryLoaded(.success(let agents)):
                state.isLoadingAgents = false
                state.availableACPAgents = agents
                // Auto-connect if we have a saved agent selection and aren't already connected
                if !state.acpConnection.isConnected && !state.acpConnection.isConnecting,
                   let savedId = state.settings.selectedACPAgentId,
                   agents.contains(where: { $0.id == savedId }) {
                    return .send(.connectACPAgent)
                }
                return .none

            case .acpRegistryLoaded(.failure(let error)):
                state.isLoadingAgents = false
                state.$acpConnection.withLock { $0.error = error.localizedDescription }
                return .none

            case .selectACPAgent(let agentId):
                state.settings.selectedACPAgentId = agentId
                return saveSettings(state.settings)

            case .connectACPAgent:
                guard let agentId = state.settings.selectedACPAgentId,
                      let entry = state.availableACPAgents.first(where: { $0.id == agentId }) else {
                    state.$acpConnection.withLock { $0.error = "No agent selected." }
                    return .none
                }
                state.$acpConnection.withLock {
                    $0.error = nil
                    $0.isConnecting = true
                }
                return .run { send in
                    await send(.acpConnected(Result { try await acpClient.connect(entry) }))
                }

            case .acpConnected(.success(let name)):
                state.$acpConnection.withLock {
                    $0.isConnecting = false
                    $0.isConnected = true
                    $0.connectedAgentName = name
                    $0.error = nil
                }
                return .run { send in
                    for await _ in acpClient.onUnexpectedDisconnect() {
                        await send(.acpProcessCrashed)
                    }
                }
                .cancellable(id: CancelID.acpCrashMonitor, cancelInFlight: true)

            case .acpConnected(.failure(let error)):
                state.$acpConnection.withLock {
                    $0.isConnecting = false
                    $0.isConnected = false
                    $0.connectedAgentName = nil
                    $0.error = error.localizedDescription
                }
                return .none

            case .disconnectACPAgent:
                return .run { send in
                    await acpClient.disconnect()
                    await send(.acpDisconnected)
                }

            case .acpDisconnected:
                state.$acpConnection.withLock {
                    $0.isConnected = false
                    $0.connectedAgentName = nil
                }
                return .cancel(id: CancelID.acpCrashMonitor)

            case .acpProcessCrashed:
                state.$acpConnection.withLock {
                    $0.isConnected = false
                    $0.isConnecting = false
                    $0.connectedAgentName = nil
                    $0.error = "Agent process terminated unexpectedly."
                }
                return .none
            }
        }
        .ifLet(\.jobDetail, action: \.jobDetail) {
            JobDetailFeature()
        }
    }

    private func saveJobs(_ jobs: IdentifiedArrayOf<JobApplication>) -> Effect<Action> {
        .run { send in
            do {
                try await persistence.saveJobs(Array(jobs))
            } catch {
                await send(.saveFailed("Failed to save jobs: \(error.localizedDescription)"))
            }
        }
        .cancellable(id: CancelID.save, cancelInFlight: true)
    }

    private func saveSettings(_ settings: AppSettings) -> Effect<Action> {
        .run { send in
            do {
                try await persistence.saveSettings(settings)
            } catch {
                await send(.saveFailed("Failed to save settings: \(error.localizedDescription)"))
            }
        }
        .cancellable(id: CancelID.saveSettings, cancelInFlight: true)
    }
}
