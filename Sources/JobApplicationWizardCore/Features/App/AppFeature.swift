import AppKit
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
    private enum CancelID { case acpCrashMonitor, save, saveSettings, bindingDebounce }

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
        public var cuttle: CuttleFeature.State = CuttleFeature.State()
        public var cuttleOnboarding: CuttleOnboardingFeature.State = CuttleOnboardingFeature.State()
        public var history: HistoryFeature.State = HistoryFeature.State()
        public var saveError: String? = nil
        public var showImportAllConfirm: Bool = false
        public var pendingImportAll: AppDataExport? = nil

        // ACP state
        @Shared(.inMemory("acpConnection")) public var acpConnection = ACPConnectionState()
        public var availableACPAgents: [ACPAgentEntry] = []
        public var isLoadingAgents: Bool = false

        // Agent action review
        public var pendingAgentReview: PendingAgentReview? = nil
        public var showAgentReviewSheet: Bool = false

        // Document processing
        public var processingDocumentJobIds: Set<UUID> = []

        // Undo/redo stacks
        public var undoStack: [HistoryEvent] = []
        public var redoStack: [HistoryEvent] = []

        // Calendar
        public var calendar: CalendarFeature.State = CalendarFeature.State()

        // Binding debounce tracking
        public var lastBindingJobId: UUID? = nil

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
        case cuttle(CuttleFeature.Action)
        case history(HistoryFeature.Action)
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
        // Cuttle persistence
        case saveCuttleState
        // Agent actions
        case agentActionModeChanged(AgentActionMode)
        case autoProcessDocumentsChanged(Bool)
        case applyAgentActions([AgentAction], String, UUID)
        case confirmAgentReview
        case cancelAgentReview
        case toggleAgentReviewAction(Int)
        // Documents
        case documentDropped(UUID, [URL])
        case documentExtracted(UUID, JobDocument)
        case documentExtractionFailed(String)
        case processDocumentWithAI(jobId: UUID, documentId: UUID)
        // Undo/redo
        case undo
        case redo
        // History debounce
        case recordBindingEdit(UUID)
        // Calendar
        case calendar(CalendarFeature.Action)
        // Cuttle onboarding
        case cuttleOnboarding(CuttleOnboardingFeature.Action)
        case replayCuttleTour
    }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.acpClient) var acpClient
    @Dependency(\.acpRegistryClient) var acpRegistry
    @Dependency(\.historyClient) var historyClient
    @Dependency(\.documentClient) var documentClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.addJob, action: \.addJob) { AddJobFeature() }
        Scope(state: \.cuttle, action: \.cuttle) { CuttleFeature() }
        Scope(state: \.cuttleOnboarding, action: \.cuttleOnboarding) { CuttleOnboardingFeature() }
        Scope(state: \.history, action: \.history) { HistoryFeature() }
        Scope(state: \.calendar, action: \.calendar) { CalendarFeature() }
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .run { send in
                        async let jobs = Result { try await persistence.loadJobs() }
                        async let settings = Result { try await persistence.loadSettings() }
                        let apiKey = keychain.loadAPIKey()
                        await send(.jobsLoaded(await jobs))
                        await send(.settingsLoaded(await settings))
                        await send(.saveSettingsKey(apiKey))
                    },
                    .send(.calendar(.startListening))
                )

            case .jobsLoaded(.success(let jobs)):
                state.jobs = IdentifiedArray(uniqueElements: jobs)
                state.cuttle.jobs = Array(state.jobs)
                if state.jobs.isEmpty {
                    state.showOnboarding = true
                }
                return .none

            case .jobsLoaded(.failure(let error)):
                state.saveError = "Failed to load jobs: \(error.localizedDescription). Your data file may be corrupted; check jobs.json or jobs.backup.json in Application Support."
                return .none

            case .settingsLoaded(.success(let settings)):
                state.settings = settings
                state.viewMode = settings.defaultViewMode
                state.$acpConnection.withLock { $0.aiProvider = settings.aiProvider }
                // Restore Cuttle state from settings
                state.cuttle.userProfile = settings.userProfile
                let context = settings.cuttleContext ?? .global
                // Trigger Cuttle onboarding if not completed and app onboarding is not showing
                let shouldStartOnboarding = !settings.hasCuttleOnboardingCompleted && !state.showOnboarding
                if shouldStartOnboarding {
                    state.cuttleOnboarding.aiReady = state.acpConnection.isConnected || !state.claudeAPIKey.isEmpty
                }
                return .merge(
                    .send(.cuttle(.restoreFromSettings(
                        context,
                        settings.globalChatHistory,
                        settings.statusChatHistories
                    ))),
                    settings.aiProvider == .acpAgent ? .send(.fetchACPRegistry) : .none,
                    shouldStartOnboarding ? .send(.cuttleOnboarding(.start)) : .none
                )

            case .settingsLoaded(.failure):
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
                    var detail = JobDetailFeature.State(
                        job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                    )
                    if let previousTab { detail.selectedTab = previousTab }
                    state.jobDetail = detail
                } else {
                    state.jobDetail = nil
                }
                return .none

            case .moveJob(let id, let newStatus):
                guard var job = state.jobs[id: id] else { return .none }
                let oldStatus = job.status
                job.status = newStatus
                if newStatus == .applied && job.dateApplied == nil {
                    job.dateApplied = Date()
                }
                state.jobs[id: id] = job
                if state.jobDetail?.job.id == id {
                    state.jobDetail?.job = job
                }
                state.cuttle.jobs = Array(state.jobs)
                let event = HistoryEvent(
                    label: "Moved \(job.displayCompany) from \(oldStatus.rawValue) to \(newStatus.rawValue)",
                    source: .user,
                    command: .setStatus(jobId: id, old: oldStatus, new: newStatus)
                )
                return .merge(saveJobs(state.jobs), recordEvent(event, state: &state))

            case .deleteJob(let id):
                let snapshot = state.jobs[id: id]
                state.jobs.remove(id: id)
                if state.selectedJobID == id {
                    state.selectedJobID = nil
                    state.jobDetail = nil
                }
                state.cuttle.jobs = Array(state.jobs)
                if case .job(let cuttleJobId) = state.cuttle.currentContext, cuttleJobId == id {
                    state.cuttle.currentContext = .global
                    state.cuttle.chatMessages = state.cuttle.globalChatHistory
                    state.cuttle.tokenUsage = .zero
                    state.cuttle.error = nil
                    state.cuttle.acpSentSystemPrompt = false
                }
                var effects: [Effect<Action>] = [saveJobs(state.jobs)]
                if let snapshot {
                    let event = HistoryEvent(
                        label: "Deleted \(snapshot.displayCompany) \(snapshot.displayTitle)",
                        source: .user,
                        command: .deleteJob(jobId: id, snapshot: snapshot)
                    )
                    effects.append(recordEvent(event, state: &state))
                }
                return .merge(effects)

            case .toggleFavorite(let id):
                guard let job = state.jobs[id: id] else { return .none }
                let oldVal = job.isFavorite
                state.jobs[id: id]?.isFavorite.toggle()
                state.cuttle.jobs = Array(state.jobs)
                let event = HistoryEvent(
                    label: "\(oldVal ? "Unfavorited" : "Favorited") \(job.displayCompany)",
                    source: .user,
                    command: .toggleFavorite(jobId: id, old: oldVal, new: !oldVal)
                )
                return .merge(saveJobs(state.jobs), recordEvent(event, state: &state))

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
                state.cuttle.jobs = Array(state.jobs)
                let event = HistoryEvent(
                    label: "Added \(job.displayCompany) \(job.displayTitle)",
                    source: .user,
                    command: .addJob(jobId: job.id)
                )
                return .merge(saveJobs(state.jobs), recordEvent(event, state: &state))

            case .addJob(.delegate(.cancel)):
                state.addJob = AddJobFeature.State()
                return .none

            case .addJob:
                return .none

            case .jobDetail(.delegate(.jobUpdated(let job))):
                state.jobs[id: job.id] = job
                state.cuttle.jobs = Array(state.jobs)
                // Debounce binding edits: record history after 2s of inactivity
                state.lastBindingJobId = job.id
                return .merge(
                    saveJobs(state.jobs),
                    .run { send in
                        try await Task.sleep(for: .seconds(2))
                        await send(.recordBindingEdit(job.id))
                    }
                    .cancellable(id: CancelID.bindingDebounce, cancelInFlight: true)
                )

            case .recordBindingEdit(_):
                // The debounce timer fired; the job state is already saved.
                // We don't record individual field-level events for bindings to keep history clean.
                state.lastBindingJobId = nil
                return .none

            case .jobDetail(.delegate(.jobDeleted(let id))):
                let snapshot = state.jobs[id: id]
                state.jobs.remove(id: id)
                state.selectedJobID = nil
                state.jobDetail = nil
                state.cuttle.jobs = Array(state.jobs)
                if case .job(let cuttleJobId) = state.cuttle.currentContext, cuttleJobId == id {
                    state.cuttle.currentContext = .global
                    state.cuttle.chatMessages = state.cuttle.globalChatHistory
                    state.cuttle.tokenUsage = .zero
                    state.cuttle.error = nil
                    state.cuttle.acpSentSystemPrompt = false
                }
                var effects: [Effect<Action>] = [saveJobs(state.jobs)]
                if let snapshot {
                    let event = HistoryEvent(
                        label: "Deleted \(snapshot.displayCompany) \(snapshot.displayTitle)",
                        source: .user,
                        command: .deleteJob(jobId: id, snapshot: snapshot)
                    )
                    effects.append(recordEvent(event, state: &state))
                }
                return .merge(effects)

            case .jobDetail(.delegate(.processDocumentWithAI(let jobId, let documentId))):
                return .send(.processDocumentWithAI(jobId: jobId, documentId: documentId))

            case .jobDetail:
                return .none

            // MARK: - Cuttle

            case .cuttle(.delegate(.jobChatUpdated(let jobId, let messages))):
                state.jobs[id: jobId]?.chatHistory = messages
                state.cuttle.jobs = Array(state.jobs)
                return .merge(
                    saveJobs(state.jobs),
                    .send(.saveCuttleState)
                )

            case .cuttle(.delegate(.contextChanged(let context))):
                if case .job(let id) = context {
                    return .send(.selectJob(id))
                }
                return .none

            case .cuttle(.delegate(.agentActionsReceived(let actions, let summary))):
                guard case .job(let jobId) = state.cuttle.currentContext,
                      state.jobs[id: jobId] != nil else {
                    return .none
                }
                // Select the job so the detail pane opens
                if state.selectedJobID != jobId {
                    state.selectedJobID = jobId
                    if let job = state.jobs[id: jobId] {
                        state.jobDetail = JobDetailFeature.State(
                            job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                        )
                    }
                }
                if state.settings.agentActionMode == .applyImmediately {
                    return .send(.applyAgentActions(actions, summary, jobId))
                } else {
                    state.pendingAgentReview = PendingAgentReview(
                        jobId: jobId, actions: actions, summary: summary
                    )
                    state.showAgentReviewSheet = true
                    return .none
                }

            case .cuttle(.aiResponseReceived),
                 .cuttle(.clearChat),
                 .cuttle(.contextTransitionConfirmed),
                 .cuttle(.switchContext):
                return .send(.saveCuttleState)

            case .cuttle:
                return .none

            case .saveCuttleState:
                state.settings.cuttleContext = state.cuttle.currentContext
                state.settings.globalChatHistory = state.cuttle.globalChatHistory
                state.settings.statusChatHistories = state.cuttle.statusChatHistories
                return saveSettings(state.settings)

            // MARK: - History

            case .history(.delegate(.applyCommands(let commands))):
                for command in commands {
                    applyReversedCommand(command, state: &state)
                }
                state.cuttle.jobs = Array(state.jobs)
                // Refresh job detail if selected
                if let selectedId = state.selectedJobID, let job = state.jobs[id: selectedId] {
                    state.jobDetail = JobDetailFeature.State(
                        job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                    )
                }
                return saveJobs(state.jobs)

            case .history:
                return .none

            // MARK: - Agent Actions

            case .agentActionModeChanged(let mode):
                state.settings.agentActionMode = mode
                return saveSettings(state.settings)

            case .autoProcessDocumentsChanged(let enabled):
                state.settings.autoProcessDocuments = enabled
                return saveSettings(state.settings)

            case .applyAgentActions(let actions, let summary, let jobId):
                guard var job = state.jobs[id: jobId] else { return .none }
                let oldSnapshot = job
                var historyCommands: [HistoryCommand] = []

                for action in actions {
                    switch action {
                    case .updateField(let field, let value):
                        let oldValue: String
                        switch field {
                        case .company: oldValue = job.company; job.company = value
                        case .title: oldValue = job.title; job.title = value
                        case .location: oldValue = job.location; job.location = value
                        case .salary: oldValue = job.salary; job.salary = value
                        case .url: oldValue = job.url; job.url = value
                        case .jobDescription: oldValue = job.jobDescription; job.jobDescription = value
                        case .resumeUsed: oldValue = job.resumeUsed; job.resumeUsed = value
                        case .coverLetter: oldValue = job.coverLetter; job.coverLetter = value
                        }
                        historyCommands.append(.updateField(jobId: jobId, field: field, oldValue: oldValue, newValue: value))

                    case .setStatus(let statusStr):
                        if let newStatus = JobStatus.allCases.first(where: { $0.rawValue == statusStr }) {
                            let old = job.status
                            job.status = newStatus
                            historyCommands.append(.setStatus(jobId: jobId, old: old, new: newStatus))
                        }

                    case .addNote(let title, let body):
                        let note = Note(title: title, body: body)
                        job.noteCards.insert(note, at: 0)
                        historyCommands.append(.addNote(jobId: jobId, noteId: note.id))

                    case .updateNote(let matchTitle, let newTitle, let newBody):
                        if let idx = job.noteCards.firstIndex(where: {
                            $0.title.localizedCaseInsensitiveContains(matchTitle)
                        }) {
                            if let t = newTitle { job.noteCards[idx].title = t }
                            if let b = newBody { job.noteCards[idx].body = b }
                            job.noteCards[idx].updatedAt = Date()
                        }

                    case .addContact(let name, let title, let email):
                        let contact = Contact(name: name, title: title ?? "", email: email ?? "")
                        job.contacts.append(contact)
                        historyCommands.append(.addContact(jobId: jobId, contactId: contact.id))

                    case .updateContact(let matchName, let newName, let newTitle, let newEmail):
                        if let idx = job.contacts.firstIndex(where: {
                            $0.name.localizedCaseInsensitiveContains(matchName)
                        }) {
                            if let n = newName { job.contacts[idx].name = n }
                            if let t = newTitle { job.contacts[idx].title = t }
                            if let e = newEmail { job.contacts[idx].email = e }
                        }

                    case .addInterview(let round, let type, let dateStr):
                        var date: Date? = nil
                        if let dateStr {
                            date = ISO8601DateFormatter().date(from: dateStr)
                        }
                        let interview = InterviewRound(round: round, type: type, date: date)
                        job.interviews.append(interview)
                        historyCommands.append(.addInterview(jobId: jobId, interviewId: interview.id))

                    case .updateInterview(let round, let type, let dateStr, let interviewers, let notes):
                        if let idx = job.interviews.firstIndex(where: { $0.round == round }) {
                            if let t = type { job.interviews[idx].type = t }
                            if let dateStr {
                                job.interviews[idx].date = ISO8601DateFormatter().date(from: dateStr)
                            }
                            if let i = interviewers { job.interviews[idx].interviewers = i }
                            if let n = notes { job.interviews[idx].notes = n }
                        }

                    case .deleteNote(let matchTitle):
                        if let idx = job.noteCards.firstIndex(where: {
                            $0.title.localizedCaseInsensitiveContains(matchTitle)
                        }) {
                            let snapshot = job.noteCards[idx]
                            job.noteCards.remove(at: idx)
                            historyCommands.append(.deleteNote(jobId: jobId, snapshot: snapshot))
                        }

                    case .deleteContact(let matchName):
                        if let idx = job.contacts.firstIndex(where: {
                            $0.name.localizedCaseInsensitiveContains(matchName)
                        }) {
                            let snapshot = job.contacts[idx]
                            job.contacts.remove(at: idx)
                            historyCommands.append(.deleteContact(jobId: jobId, snapshot: snapshot))
                        }

                    case .deleteInterview(let round):
                        if let idx = job.interviews.firstIndex(where: { $0.round == round }) {
                            let snapshot = job.interviews[idx]
                            job.interviews.remove(at: idx)
                            historyCommands.append(.deleteInterview(jobId: jobId, snapshot: snapshot))
                        }

                    case .addLabel(let labelName):
                        if let preset = JobLabel.presets.first(where: { $0.name.lowercased() == labelName.lowercased() }) {
                            job.labels.append(preset)
                            historyCommands.append(.addLabel(jobId: jobId, label: preset))
                        } else {
                            let label = JobLabel(name: labelName, colorHex: "#8E8E93")
                            job.labels.append(label)
                            historyCommands.append(.addLabel(jobId: jobId, label: label))
                        }

                    case .removeLabel(let labelName):
                        if let idx = job.labels.firstIndex(where: {
                            $0.name.localizedCaseInsensitiveContains(labelName)
                        }) {
                            let label = job.labels[idx]
                            job.labels.remove(at: idx)
                            historyCommands.append(.removeLabel(jobId: jobId, label: label))
                        }

                    case .setExcitement(let level):
                        let old = job.excitement
                        job.excitement = max(1, min(5, level))
                        historyCommands.append(.setExcitement(jobId: jobId, old: old, new: job.excitement))
                    }
                }

                state.jobs[id: jobId] = job
                state.cuttle.jobs = Array(state.jobs)
                if state.jobDetail?.job.id == jobId {
                    state.jobDetail = JobDetailFeature.State(
                        job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                    )
                }

                let event = HistoryEvent(
                    label: "AI: \(summary)",
                    source: .agent,
                    command: .replaceJob(jobId: jobId, oldSnapshot: oldSnapshot, newSnapshot: job)
                )
                return .merge(saveJobs(state.jobs), recordEvent(event, state: &state))

            case .confirmAgentReview:
                guard let review = state.pendingAgentReview else { return .none }
                state.showAgentReviewSheet = false
                let selectedActions = review.actions.enumerated()
                    .filter { review.accepted.contains($0.offset) }
                    .map(\.element)
                state.pendingAgentReview = nil
                guard !selectedActions.isEmpty else { return .none }
                return .send(.applyAgentActions(selectedActions, review.summary, review.jobId))

            case .cancelAgentReview:
                state.pendingAgentReview = nil
                state.showAgentReviewSheet = false
                return .none

            case .toggleAgentReviewAction(let index):
                if state.pendingAgentReview?.accepted.contains(index) == true {
                    state.pendingAgentReview?.accepted.remove(index)
                } else {
                    state.pendingAgentReview?.accepted.insert(index)
                }
                return .none

            // MARK: - Documents

            case .documentDropped(let jobId, let urls):
                guard state.jobs[id: jobId] != nil else { return .none }
                state.processingDocumentJobIds.insert(jobId)
                return .run { send in
                    for url in urls {
                        do {
                            let result = try await documentClient.extractText(url)
                            let doc = JobDocument(
                                filename: result.filename,
                                documentType: result.type,
                                rawText: result.text,
                                fileSize: result.size,
                                sourcePath: url.path
                            )
                            await send(.documentExtracted(jobId, doc))
                        } catch {
                            await send(.documentExtractionFailed(error.localizedDescription))
                        }
                    }
                }

            case .documentExtracted(let jobId, let doc):
                state.jobs[id: jobId]?.documents.append(doc)
                state.processingDocumentJobIds.remove(jobId)
                state.cuttle.jobs = Array(state.jobs)
                // Refresh job detail if viewing this job
                if state.jobDetail?.job.id == jobId, let job = state.jobs[id: jobId] {
                    state.jobDetail = JobDetailFeature.State(
                        job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                    )
                }
                let event = HistoryEvent(
                    label: "Added document \(doc.filename) to \(state.jobs[id: jobId]?.displayCompany ?? "job")",
                    source: .user,
                    command: .addDocument(jobId: jobId, documentId: doc.id)
                )
                // Switch Cuttle context to the target job, expand chat, then process with AI
                state.cuttle.isExpanded = true
                let historyEffect = recordEvent(event, state: &state)
                return .merge(
                    saveJobs(state.jobs),
                    historyEffect,
                    .send(.cuttle(.switchContext(.job(jobId)))),
                    .send(.processDocumentWithAI(jobId: jobId, documentId: doc.id))
                )

            case .documentExtractionFailed(let error):
                state.saveError = "Document extraction failed: \(error)"
                state.processingDocumentJobIds = []
                return .none

            case .processDocumentWithAI(let jobId, let documentId):
                guard let job = state.jobs[id: jobId],
                      let doc = job.documents.first(where: { $0.id == documentId }) else {
                    return .none
                }
                // Send a message to Cuttle to process the document
                let message = "Please review the document '\(doc.filename)' (shown in the job context) and organize it into the appropriate fields."
                return .send(.cuttle(.sendMessage(message)))

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
                let existingIDs = Set(state.jobs.ids)
                let newJobs = imported.filter { !existingIDs.contains($0.id) }
                for job in newJobs { state.jobs.append(job) }
                if !newJobs.isEmpty { state.filterStatus = nil }
                state.cuttle.jobs = Array(state.jobs)
                return saveJobs(state.jobs)

            case .dismissOnboarding:
                state.showOnboarding = false
                // Start Cuttle onboarding if not yet completed
                if !state.settings.hasCuttleOnboardingCompleted {
                    state.cuttleOnboarding.aiReady = state.acpConnection.isConnected || !state.claudeAPIKey.isEmpty
                    return .send(.cuttleOnboarding(.start))
                }
                return .none

            case .saveSettingsKey(let key):
                state.claudeAPIKey = key
                state.jobDetail?.apiKey = key
                state.cuttle.apiKey = key
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
                state.cuttle.userProfile = profile
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
                state.cuttle.jobs = []
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
                state.cuttle.jobs = Array(state.jobs)
                state.cuttle.userProfile = export.settings.userProfile
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

            // MARK: - Calendar Delegates

            case .calendar(.delegate(.eventLinked(let jobId, let interviewId, let event))):
                if var job = state.jobs[id: jobId],
                   let idx = job.interviews.firstIndex(where: { $0.id == interviewId }) {
                    job.interviews[idx].calendarEventIdentifier = event.id
                    job.interviews[idx].calendarEventTitle = event.title
                    job.interviews[idx].date = event.startDate
                    if job.interviews[idx].type.isEmpty {
                        job.interviews[idx].type = event.title
                    }
                    state.jobs[id: jobId] = job
                    if state.jobDetail?.job.id == jobId {
                        state.jobDetail = JobDetailFeature.State(
                            job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                        )
                    }
                }
                state.cuttle.jobs = Array(state.jobs)
                return saveJobs(state.jobs)

            case .calendar(.delegate(.eventUnlinked(let jobId, let interviewId))):
                if var job = state.jobs[id: jobId],
                   let idx = job.interviews.firstIndex(where: { $0.id == interviewId }) {
                    job.interviews[idx].calendarEventIdentifier = nil
                    job.interviews[idx].calendarEventTitle = nil
                    state.jobs[id: jobId] = job
                    if state.jobDetail?.job.id == jobId {
                        state.jobDetail = JobDetailFeature.State(
                            job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                        )
                    }
                }
                state.cuttle.jobs = Array(state.jobs)
                return saveJobs(state.jobs)

            case .calendar(.delegate(.interviewDatesUpdated(let updates))):
                var effects: [Effect<Action>] = []
                for update in updates {
                    if var job = state.jobs[id: update.jobId],
                       let roundIdx = job.interviews.firstIndex(where: { $0.id == update.interviewId }) {
                        job.interviews[roundIdx].date = update.newDate
                        state.jobs[id: update.jobId] = job
                    }
                    if state.jobDetail?.job.id == update.jobId,
                       let roundIdx = state.jobDetail?.interviews.firstIndex(where: { $0.id == update.interviewId }) {
                        state.jobDetail?.interviews[roundIdx].date = update.newDate
                        state.jobDetail?.syncJobFromFields()
                    }
                    let event = HistoryEvent(
                        label: "Calendar sync updated Round \(update.roundNumber) for \(update.jobCompany)",
                        source: .system,
                        command: .updateInterviewDate(
                            jobId: update.jobId,
                            interviewId: update.interviewId,
                            oldDate: update.oldDate,
                            newDate: update.newDate
                        )
                    )
                    effects.append(recordEvent(event, state: &state))
                }
                effects.append(saveJobs(state.jobs))
                return .merge(effects)

            case .calendar(.delegate(.missingEventsDetected)):
                // Warnings are stored in CalendarFeature.State.syncWarnings
                return .none

            case .calendar(.delegate(.needsJobsForSync)):
                return .send(.calendar(.performSync(state.jobs)))

            case .calendar:
                return .none

            // MARK: - Undo / Redo

            case .undo:
                guard let event = state.undoStack.popLast() else { return .none }
                let reversed = event.command.reversed()
                applyReversedCommand(reversed, state: &state)
                // Push to redo stack with the original (un-reversed) command
                state.redoStack.append(event)
                state.cuttle.jobs = Array(state.jobs)
                if let selectedId = state.selectedJobID, let job = state.jobs[id: selectedId] {
                    state.jobDetail = JobDetailFeature.State(
                        job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                    )
                }
                return saveJobs(state.jobs)

            case .redo:
                guard let event = state.redoStack.popLast() else { return .none }
                // Re-apply the original command (forward direction)
                applyForwardCommand(event.command, state: &state)
                state.undoStack.append(event)
                state.cuttle.jobs = Array(state.jobs)
                if let selectedId = state.selectedJobID, let job = state.jobs[id: selectedId] {
                    state.jobDetail = JobDetailFeature.State(
                        job: job, apiKey: state.claudeAPIKey, userProfile: state.settings.userProfile
                    )
                }
                return saveJobs(state.jobs)

            // MARK: - Cuttle Onboarding

            case .cuttleOnboarding(.delegate(.completed)),
                 .cuttleOnboarding(.delegate(.dismissed)):
                state.settings.hasCuttleOnboardingCompleted = true
                return saveSettings(state.settings)

            case .cuttleOnboarding(.delegate(.expandCuttle)):
                state.cuttle.isExpanded = true
                return .none

            case .cuttleOnboarding(.delegate(.collapseCuttle)):
                state.cuttle.isExpanded = false
                return .none

            case .cuttleOnboarding(.delegate(.agentConnected(let agentId, let agentName))):
                state.$acpConnection.withLock {
                    $0.isConnected = true
                    $0.connectedAgentName = agentName
                }
                state.settings.selectedACPAgentId = agentId
                return saveSettings(state.settings)

            case .cuttleOnboarding:
                return .none

            case .replayCuttleTour:
                state.settings.hasCuttleOnboardingCompleted = false
                state.cuttleOnboarding.aiReady = state.acpConnection.isConnected || !state.claudeAPIKey.isEmpty
                return .merge(
                    saveSettings(state.settings),
                    .send(.cuttleOnboarding(.start))
                )
            }
        }
        .ifLet(\.jobDetail, action: \.jobDetail) {
            JobDetailFeature()
        }
    }

    // MARK: - Helpers

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

    private func recordEvent(_ event: HistoryEvent, state: inout State) -> Effect<Action> {
        state.undoStack.append(event)
        state.redoStack.removeAll()
        return .run { [historyClient] _ in
            await historyClient.record(event)
        }
    }

    /// Applies a reversed command to the current state for undo/revert operations.
    private func applyReversedCommand(_ command: HistoryCommand, state: inout State) {
        switch command {
        case .updateField(let jobId, let field, _, let newValue):
            // newValue is the target value after reversal
            switch field {
            case .company: state.jobs[id: jobId]?.company = newValue
            case .title: state.jobs[id: jobId]?.title = newValue
            case .location: state.jobs[id: jobId]?.location = newValue
            case .salary: state.jobs[id: jobId]?.salary = newValue
            case .url: state.jobs[id: jobId]?.url = newValue
            case .jobDescription: state.jobs[id: jobId]?.jobDescription = newValue
            case .resumeUsed: state.jobs[id: jobId]?.resumeUsed = newValue
            case .coverLetter: state.jobs[id: jobId]?.coverLetter = newValue
            }

        case .setStatus(let jobId, _, let newStatus):
            state.jobs[id: jobId]?.status = newStatus

        case .addNote(_, _):
            // "Add note" as a reversed command means we need to restore the note
            // This is a limitation; for now we just skip
            break

        case .deleteNote(let jobId, let snapshot):
            state.jobs[id: jobId]?.noteCards.insert(snapshot, at: 0)

        case .addContact(_, _):
            break

        case .deleteContact(let jobId, let snapshot):
            state.jobs[id: jobId]?.contacts.append(snapshot)

        case .addInterview(_, _):
            break

        case .deleteInterview(let jobId, let snapshot):
            state.jobs[id: jobId]?.interviews.append(snapshot)

        case .addLabel(let jobId, let label):
            state.jobs[id: jobId]?.labels.append(label)

        case .removeLabel(let jobId, let label):
            state.jobs[id: jobId]?.labels.removeAll { $0.name == label.name }

        case .setExcitement(let jobId, _, let newVal):
            state.jobs[id: jobId]?.excitement = newVal

        case .toggleFavorite(let jobId, _, let newVal):
            state.jobs[id: jobId]?.isFavorite = newVal

        case .addJob(let jobId):
            // Reversing addJob = deleting. But we need a snapshot, which we don't have here.
            state.jobs.remove(id: jobId)

        case .deleteJob(_, let snapshot):
            // Reversing deleteJob = re-adding
            state.jobs.append(snapshot)

        case .addDocument(_, _):
            break

        case .deleteDocument(let jobId, let snapshot):
            state.jobs[id: jobId]?.documents.append(snapshot)

        case .replaceJob(let jobId, _, let newSnapshot):
            // For reversed commands, newSnapshot is the target (swapped by .reversed())
            state.jobs[id: jobId] = newSnapshot

        case .compound(let commands):
            for cmd in commands {
                applyReversedCommand(cmd, state: &state)
            }

        case .updateInterviewDate(let jobId, let interviewId, _, let newDate):
            if var job = state.jobs[id: jobId],
               let roundIdx = job.interviews.firstIndex(where: { $0.id == interviewId }) {
                job.interviews[roundIdx].date = newDate
                state.jobs[id: jobId] = job
            }
            if state.jobDetail?.job.id == jobId,
               let roundIdx = state.jobDetail?.interviews.firstIndex(where: { $0.id == interviewId }) {
                state.jobDetail?.interviews[roundIdx].date = newDate
                state.jobDetail?.syncJobFromFields()
            }
        }
    }

    /// Applies a command in its original (forward) direction for redo operations.
    private func applyForwardCommand(_ command: HistoryCommand, state: inout State) {
        switch command {
        case .updateField(let jobId, let field, _, let newValue):
            switch field {
            case .company: state.jobs[id: jobId]?.company = newValue
            case .title: state.jobs[id: jobId]?.title = newValue
            case .location: state.jobs[id: jobId]?.location = newValue
            case .salary: state.jobs[id: jobId]?.salary = newValue
            case .url: state.jobs[id: jobId]?.url = newValue
            case .jobDescription: state.jobs[id: jobId]?.jobDescription = newValue
            case .resumeUsed: state.jobs[id: jobId]?.resumeUsed = newValue
            case .coverLetter: state.jobs[id: jobId]?.coverLetter = newValue
            }

        case .setStatus(let jobId, _, let newStatus):
            state.jobs[id: jobId]?.status = newStatus

        case .addNote(_, _):
            // Re-adding a note without a snapshot; limited
            break

        case .deleteNote(let jobId, let snapshot):
            state.jobs[id: jobId]?.noteCards.removeAll { $0.id == snapshot.id }

        case .addContact(_, _):
            break

        case .deleteContact(let jobId, let snapshot):
            state.jobs[id: jobId]?.contacts.removeAll { $0.id == snapshot.id }

        case .addInterview(_, _):
            break

        case .deleteInterview(let jobId, let snapshot):
            state.jobs[id: jobId]?.interviews.removeAll { $0.id == snapshot.id }

        case .addLabel(let jobId, let label):
            state.jobs[id: jobId]?.labels.append(label)

        case .removeLabel(let jobId, let label):
            state.jobs[id: jobId]?.labels.removeAll { $0.name == label.name }

        case .setExcitement(let jobId, _, let newVal):
            state.jobs[id: jobId]?.excitement = newVal

        case .toggleFavorite(let jobId, _, let newVal):
            state.jobs[id: jobId]?.isFavorite = newVal

        case .addJob(_):
            // Can't fully re-add without snapshot
            break

        case .deleteJob(let jobId, _):
            state.jobs.remove(id: jobId)

        case .addDocument(_, _):
            break

        case .deleteDocument(let jobId, let snapshot):
            state.jobs[id: jobId]?.documents.removeAll { $0.id == snapshot.id }

        case .replaceJob(let jobId, _, let newSnapshot):
            state.jobs[id: jobId] = newSnapshot

        case .compound(let commands):
            for cmd in commands {
                applyForwardCommand(cmd, state: &state)
            }

        case .updateInterviewDate(let jobId, let interviewId, _, let newDate):
            if var job = state.jobs[id: jobId],
               let roundIdx = job.interviews.firstIndex(where: { $0.id == interviewId }) {
                job.interviews[roundIdx].date = newDate
                state.jobs[id: jobId] = job
            }
            if state.jobDetail?.job.id == jobId,
               let roundIdx = state.jobDetail?.interviews.firstIndex(where: { $0.id == interviewId }) {
                state.jobDetail?.interviews[roundIdx].date = newDate
                state.jobDetail?.syncJobFromFields()
            }
        }
    }
}
