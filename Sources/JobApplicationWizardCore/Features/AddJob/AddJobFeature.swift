import ComposableArchitecture
import Foundation

// MARK: - Entry Mode

public enum EntryMode: String, CaseIterable, Identifiable, Equatable, Sendable {
    case aiImport = "AI Import"
    case manual = "Manual Entry"
    public var id: Self { self }
}

// MARK: - Import Progress

public enum ImportProgress: Equatable, Sendable {
    case idle
    case fetching
    case enriching
    case done
}

@Reducer
public struct AddJobFeature {
    public init() {}

    private enum CancelID { case urlImport, aiParse }

    @ObservableState
    public struct State: Equatable {
        public var entryMode: EntryMode = .manual
        public var company = ""
        public var title = ""
        public var url = ""
        public var location = ""
        public var salary = ""
        public var status: JobStatus = .wishlist
        public var excitement: Int = 3
        public var jobDescription = ""
        public var selectedLabelNames: Set<String> = []

        // Paste-based AI import
        public var pastedText = ""
        public var isParsing: Bool = false
        public var parseError: String?
        public var hasParsed: Bool = false

        // URL import
        public var isImporting: Bool = false
        public var importError: String?
        public var importProgress: ImportProgress = .idle
        public var apiKey: String = ""
        public var aiProvider: AIProvider = .acpAgent
        public var importedATSProvider: ATSProvider?

        // ACP connection (shared state, read-only)
        @SharedReader(.inMemory("acpConnection")) public var acpConnection = ACPConnectionState()

        public var canSave: Bool { !company.isEmpty || !title.isEmpty }
        public var canImport: Bool {
            !url.isEmpty && !isImporting && URL(string: url) != nil
        }
        public var canParse: Bool {
            let hasText = !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasURL = !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return (hasText || hasURL) && !isParsing
        }
        /// True after an import attempt has completed (success or failure).
        public var hasAttemptedImport: Bool {
            importedATSProvider != nil || importError != nil
        }
        /// True when AI enrichment is available (ACP agent or Claude API key configured).
        public var hasAIAgent: Bool {
            aiProvider == .acpAgent || !apiKey.isEmpty
        }

        public init() {}

        public func buildJob() -> JobApplication {
            var job = JobApplication()
            job.company = company
            job.title = title
            job.url = url
            job.location = location
            job.salary = salary
            job.status = status
            job.excitement = excitement
            job.jobDescription = jobDescription
            job.labels = JobLabel.presets.filter { selectedLabelNames.contains($0.name) }
            job.atsProvider = importedATSProvider
            if status == .applied { job.dateApplied = Date() }
            return job
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toggleLabel(String)
        case setExcitement(Int)
        case saveTapped
        case cancelTapped
        case importURLTapped
        case importResponse(Result<ScrapedJobData, Error>)
        case enrichmentResponse(Result<ScrapedJobData, Error>)
        case dismissImportError
        case createFromPasteTapped
        case parseResponse(Result<ScrapedJobData, Error>)
        case dismissParseError
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case save(JobApplication)
            case cancel
        }
    }

    @Dependency(\.jobURLClient) var jobURLClient
    @Dependency(\.claudeClient) var claudeClient
    @Dependency(\.acpClient) var acpClient

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .toggleLabel(let name):
                if state.selectedLabelNames.contains(name) {
                    state.selectedLabelNames.remove(name)
                } else {
                    state.selectedLabelNames.insert(name)
                }
                return .none

            case .setExcitement(let value):
                state.excitement = value
                return .none

            case .saveTapped:
                let job = state.buildJob()
                return .send(.delegate(.save(job)))

            case .cancelTapped:
                return .send(.delegate(.cancel))

            // MARK: - AI Import from pasted text

            case .createFromPasteTapped:
                let text = state.pastedText.trimmingCharacters(in: .whitespacesAndNewlines)

                // If the pasted text is just a URL, route through the URL import flow
                if !text.isEmpty, let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                    state.url = text
                    state.pastedText = ""
                    return .send(.importURLTapped)
                }

                // If no pasted text but URL is present, route through URL import
                if text.isEmpty {
                    guard !state.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
                    return .send(.importURLTapped)
                }

                state.isParsing = true
                state.parseError = nil

                let useACP = state.acpConnection.aiProvider == .acpAgent && state.acpConnection.isConnected
                let acpClient = self.acpClient
                let claudeClient = self.claudeClient
                let apiKey = state.apiKey

                return .run { send in
                    await send(.parseResponse(Result {
                        let responseText: String
                        if useACP {
                            let prompt = jobParsePromptACP(for: text)
                            let (text, _) = try await acpClient.sendPrompt(prompt, [])
                            responseText = text
                        } else {
                            let userPrompt = jobParseUserPrompt(for: text)
                            let (text, _, _) = try await claudeClient.chat(
                                apiKey, jobParseSystemPrompt, [ChatMessage(role: .user, content: userPrompt)], false
                            )
                            responseText = text
                        }
                        return try parseJobJSON(responseText)
                    }))
                }
                .cancellable(id: CancelID.aiParse, cancelInFlight: true)

            case .parseResponse(.success(let parsed)):
                state.isParsing = false
                state.hasParsed = true
                applyScrapedData(&state, parsed)
                state.entryMode = .manual
                return .none

            case .parseResponse(.failure(let error)):
                state.isParsing = false
                state.parseError = error.localizedDescription
                return .none

            case .dismissParseError:
                state.parseError = nil
                return .none

            // MARK: - URL Import

            case .importURLTapped:
                guard let url = URL(string: state.url),
                      let scheme = url.scheme?.lowercased(),
                      (scheme == "http" || scheme == "https"),
                      url.host != nil else {
                    state.importError = "Please enter a valid HTTP or HTTPS URL"
                    return .none
                }
                state.isImporting = true
                state.importError = nil
                state.importProgress = .fetching
                let jobURLClient = self.jobURLClient
                return .run { send in
                    await send(.importResponse(Result {
                        try await jobURLClient.fetchJobData(url)
                    }))
                }
                .cancellable(id: CancelID.urlImport, cancelInFlight: true)

            case .importResponse(.success(let scraped)):
                state.importProgress = .enriching
                // Always apply scraped data immediately so it is not lost if enrichment fails
                applyScrapedData(&state, scraped)

                // Decide whether AI enrichment is available and needed
                let useACP = state.acpConnection.aiProvider == .acpAgent && state.acpConnection.isConnected
                let hasAI = useACP || !state.apiKey.isEmpty
                if scraped.isComplete || !hasAI {
                    state.isImporting = false
                    state.importProgress = .done
                    state.entryMode = .manual
                    return .none
                }
                // Enrich via ACP or Claude API
                let acpClient = self.acpClient
                let claudeClient = self.claudeClient
                let apiKey = state.apiKey
                return .run { send in
                    await send(.enrichmentResponse(Result {
                        try await enrichJobData(
                            scraped: scraped,
                            useACP: useACP,
                            acpSend: acpClient.sendPrompt,
                            chat: claudeClient.chat,
                            apiKey: apiKey
                        )
                    }))
                }
                .cancellable(id: CancelID.urlImport, cancelInFlight: true)

            case .importResponse(.failure(let error)):
                state.isImporting = false
                state.importProgress = .idle
                state.importError = error.localizedDescription
                return .none

            case .enrichmentResponse(.success(let enriched)):
                applyScrapedData(&state, enriched)
                state.isImporting = false
                state.importProgress = .done
                state.entryMode = .manual
                return .none

            case .enrichmentResponse(.failure(let error)):
                state.isImporting = false
                state.importProgress = .idle
                state.importError = "Enrichment failed: \(error.localizedDescription)"
                return .none

            case .dismissImportError:
                state.importError = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// Populate empty form fields from scraped data; never overwrites user-entered values.
    private func applyScrapedData(_ state: inout State, _ data: ScrapedJobData) {
        if state.title.isEmpty { state.title = data.title }
        if state.company.isEmpty { state.company = data.company }
        if state.location.isEmpty { state.location = data.location }
        if state.salary.isEmpty { state.salary = data.salary }
        if state.jobDescription.isEmpty {
            var desc = data.description
            if !data.requirements.isEmpty {
                desc += "\n\nRequirements:\n\(data.requirements)"
            }
            state.jobDescription = desc
        }
        state.importedATSProvider = data.atsProvider
    }
}
