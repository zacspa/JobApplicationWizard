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
        public var pendingMoveJobID: UUID? = nil
        public var pendingMoveStatus: JobStatus? = nil
        public var showIncompleteTasksAlert: Bool = false

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
        case jobsLoaded([JobApplication])
        case settingsLoaded(AppSettings)
        case searchQueryChanged(String)
        case filterStatusChanged(JobStatus?)
        case viewModeChanged(ViewMode)
        case selectJob(UUID?)
        case moveJobRequested(UUID, JobStatus)
        case moveJobAlertContinue
        case moveJobAlertCancel
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
    }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.keychainClient) var keychain

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.addJob, action: \.addJob) { AddJobFeature() }
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    async let jobs = persistence.loadJobs()
                    async let settings = persistence.loadSettings()
                    let apiKey = keychain.loadAPIKey()
                    await send(.jobsLoaded((try? await jobs) ?? []))
                    await send(.settingsLoaded((try? await settings) ?? AppSettings()))
                    await send(.saveSettingsKey(apiKey))
                }

            case .jobsLoaded(let jobs):
                state.jobs = IdentifiedArray(uniqueElements: jobs)
                if state.jobs.isEmpty {
                    state.showOnboarding = true
                }
                return .none

            case .settingsLoaded(let settings):
                state.settings = settings
                state.viewMode = settings.defaultViewMode
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
                    state.jobDetail = JobDetailFeature.State(job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile)
                } else {
                    state.jobDetail = nil
                }
                return .none

            case .moveJobRequested(let id, let status):
                guard let job = state.jobs[id: id] else { return .none }
                if !job.hasIncompleteCurrentTasks {
                    return .send(.moveJob(id, status))
                } else {
                    state.pendingMoveJobID = id
                    state.pendingMoveStatus = status
                    state.showIncompleteTasksAlert = true
                    return .none
                }

            case .moveJobAlertContinue:
                guard let id = state.pendingMoveJobID, let status = state.pendingMoveStatus else { return .none }
                state.pendingMoveJobID = nil
                state.pendingMoveStatus = nil
                state.showIncompleteTasksAlert = false
                return .send(.moveJob(id, status))

            case .moveJobAlertCancel:
                state.pendingMoveJobID = nil
                state.pendingMoveStatus = nil
                state.showIncompleteTasksAlert = false
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
                state.jobDetail = JobDetailFeature.State(job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile)
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
                return .run { _ in try? await persistence.saveJobs([]) }
            }
        }
        .ifLet(\.jobDetail, action: \.jobDetail) {
            JobDetailFeature()
        }
    }

    private func saveJobs(_ jobs: IdentifiedArrayOf<JobApplication>) -> Effect<Action> {
        .run { _ in try? await persistence.saveJobs(Array(jobs)) }
    }

    private func saveSettings(_ settings: AppSettings) -> Effect<Action> {
        .run { _ in try? await persistence.saveSettings(settings) }
    }
}
