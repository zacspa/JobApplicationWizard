import ComposableArchitecture
import Foundation
import AppKit

@Reducer
public struct JobDetailFeature {
    @ObservableState
    public struct State: Equatable {
        // Source of truth
        public var job: JobApplication

        // Flat editable fields (synced to/from job on BindingReducer changes)
        public var company: String
        public var title: String
        public var location: String
        public var salary: String
        public var url: String
        public var noteCards: [Note]
        public var jobDescription: String
        public var resumeUsed: String
        public var labels: [JobLabel]
        public var contacts: [Contact]
        public var interviews: [InterviewRound]

        // UI state
        public var selectedTab: Tab = .overview
        public var showDeleteConfirm: Bool = false

        // PDF state
        public var isGeneratingPDF: Bool = false
        public var pdfError: String? = nil
        public var showCopied: Bool = false

        // AI state
        public var aiSelectedAction: AIAction = .chat
        public var aiInput: String = ""
        public var chatMessages: [ChatMessage] = []
        public var aiIsLoading: Bool = false
        public var aiError: String? = nil
        public var apiKey: String
        public var userProfile: UserProfile
        public var aiTokenUsage: AITokenUsage = .zero
        @SharedReader(.inMemory("acpConnection")) public var acpConnection = ACPConnectionState()

        public enum Tab: String, CaseIterable, Equatable {
            case overview = "Overview"
            case description = "Description"
            case notes = "Notes"
            case contacts = "Contacts"
            case interviews = "Interviews"
            case ai = "AI"
        }

        public init(job: JobApplication, apiKey: String = "", userProfile: UserProfile = UserProfile()) {
            self.job = job
            self.company = job.company
            self.title = job.title
            self.location = job.location
            self.salary = job.salary
            self.url = job.url
            self.noteCards = job.noteCards
            self.jobDescription = job.jobDescription
            self.resumeUsed = job.resumeUsed
            self.labels = job.labels
            self.contacts = job.contacts
            self.interviews = job.interviews
            self.apiKey = apiKey
            self.userProfile = userProfile
            // acpConnection is automatically shared — no passthrough needed
        }

        // Build updated job from current flat fields
        public mutating func syncJobFromFields() {
            job.company = company
            job.title = title
            job.location = location
            job.salary = salary
            job.url = url
            job.noteCards = noteCards
            job.jobDescription = jobDescription
            job.resumeUsed = resumeUsed
            job.labels = labels
            job.contacts = contacts
            job.interviews = interviews
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case selectTab(State.Tab)
        case setExcitement(Int)
        case toggleFavorite
        case moveJob(JobStatus)
        case markApplied
        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
        // Notes
        case addNote
        case deleteNote(UUID)
        // Contacts / Interviews
        case addContact
        case deleteContact(IndexSet)
        case addInterview
        case deleteInterview(IndexSet)
        // Description PDF
        case printTapped
        case savePDFTapped
        case viewPDFTapped
        case copyDescriptionTapped
        case clearCopied
        case pdfSaved(Result<String, Error>)
        // AI
        case sendMessage
        case clearChat
        case aiResponseReceived(Result<(String, AITokenUsage), Error>)
        // Delegate
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case jobUpdated(JobApplication)
            case jobDeleted(UUID)
        }
    }

    @Dependency(\.pdfClient) var pdfClient
    @Dependency(\.claudeClient) var claudeClient
    @Dependency(\.acpClient) var acpClient

    public init() {}

    private enum CancelID { case aiRequest }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                state.syncJobFromFields()
                return .send(.delegate(.jobUpdated(state.job)))

            case .selectTab(let tab):
                state.selectedTab = tab
                return .none

            case .setExcitement(let value):
                state.job.excitement = value
                return .send(.delegate(.jobUpdated(state.job)))

            case .toggleFavorite:
                state.job.isFavorite.toggle()
                return .send(.delegate(.jobUpdated(state.job)))

            case .moveJob(let status):
                state.job.status = status
                if status == .applied && state.job.dateApplied == nil {
                    state.job.dateApplied = Date()
                }
                return .send(.delegate(.jobUpdated(state.job)))

            case .markApplied:
                state.job.dateApplied = Date()
                state.job.status = .applied
                return .send(.delegate(.jobUpdated(state.job)))

            case .deleteTapped:
                state.showDeleteConfirm = true
                return .none

            case .deleteConfirmed:
                state.showDeleteConfirm = false
                return .send(.delegate(.jobDeleted(state.job.id)))

            case .deleteCancelled:
                state.showDeleteConfirm = false
                return .none

            case .addNote:
                state.noteCards.insert(Note(), at: 0)
                state.syncJobFromFields()
                return .send(.delegate(.jobUpdated(state.job)))

            case .deleteNote(let id):
                state.noteCards.removeAll { $0.id == id }
                state.syncJobFromFields()
                return .send(.delegate(.jobUpdated(state.job)))

            case .addContact:
                state.contacts.append(Contact())
                state.syncJobFromFields()
                return .send(.delegate(.jobUpdated(state.job)))

            case .deleteContact(let idxs):
                state.contacts.remove(atOffsets: idxs)
                state.syncJobFromFields()
                return .send(.delegate(.jobUpdated(state.job)))

            case .addInterview:
                state.interviews.append(InterviewRound(round: state.interviews.count + 1))
                state.syncJobFromFields()
                return .send(.delegate(.jobUpdated(state.job)))

            case .deleteInterview(let idxs):
                state.interviews.remove(atOffsets: idxs)
                state.syncJobFromFields()
                return .send(.delegate(.jobUpdated(state.job)))

            case .printTapped:
                let job = state.job
                return .run { _ in await pdfClient.printJobDescription(job) }

            case .savePDFTapped:
                state.isGeneratingPDF = true
                state.pdfError = nil
                let job = state.job
                return .run { send in
                    await send(.pdfSaved(Result { try await pdfClient.generateAndSavePDF(job) }))
                }

            case .viewPDFTapped:
                if let path = state.job.pdfPath {
                    return .run { _ in await pdfClient.openPDF(path) }
                }
                return .none

            case .copyDescriptionTapped:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.jobDescription, forType: .string)
                state.showCopied = true
                return .run { send in
                    try await Task.sleep(for: .seconds(2))
                    await send(.clearCopied)
                }

            case .clearCopied:
                state.showCopied = false
                return .none

            case .pdfSaved(.success(let path)):
                state.isGeneratingPDF = false
                state.job.hasPDF = true
                state.job.pdfPath = path
                return .send(.delegate(.jobUpdated(state.job)))

            case .pdfSaved(.failure(let error)):
                state.isGeneratingPDF = false
                state.pdfError = error.localizedDescription
                return .none

            case .sendMessage:
                let rawInput = state.aiInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawInput.isEmpty else { return .none }

                // Build user message with optional preamble for specialized modes
                let userText: String
                switch state.aiSelectedAction {
                case .chat:
                    userText = rawInput
                case .tailorResume:
                    userText = "Please analyze my resume for this role and suggest tailoring:\n\n\(rawInput)"
                case .coverLetter:
                    userText = "Please write a cover letter. My background:\n\n\(rawInput)"
                case .interviewPrep:
                    userText = "Please generate interview questions and STAR-framework answers for this role.\(rawInput.isEmpty ? "" : "\n\n\(rawInput)")"
                case .analyzeFit:
                    userText = "Please analyze my fit for this role. My background:\n\n\(rawInput)"
                }

                state.chatMessages.append(ChatMessage(role: .user, content: userText))
                state.aiInput = ""
                state.aiIsLoading = true
                state.aiError = nil
                if state.aiSelectedAction != .chat {
                    state.aiSelectedAction = .chat
                }

                let job = state.job
                let profile = state.userProfile
                var profileSection = ""
                if !profile.name.isEmpty || !profile.resume.isEmpty {
                    profileSection = """

                    About the candidate:
                    \(profile.name.isEmpty ? "" : "Name: \(profile.name)\n")\
                    \(profile.currentTitle.isEmpty ? "" : "Current Title: \(profile.currentTitle)\n")\
                    \(profile.location.isEmpty ? "" : "Location: \(profile.location)\n")\
                    \(profile.skills.isEmpty ? "" : "Skills: \(profile.skills.joined(separator: ", "))\n")\
                    \(profile.targetRoles.isEmpty ? "" : "Target Roles: \(profile.targetRoles.joined(separator: ", "))\n")\
                    \(profile.preferredSalary.isEmpty ? "" : "Preferred Salary: \(profile.preferredSalary)\n")\
                    Work Preference: \(profile.workPreference.rawValue)
                    \(profile.summary.isEmpty ? "" : "\nSummary: \(profile.summary)")
                    \(profile.resume.isEmpty ? "" : "\nResume:\n\(profile.resume)")
                    """
                }
                let systemPrompt = """
                You are an expert career coach integrated into a job application tracker.
                \(profileSection)
                Target Job: \(job.displayTitle) at \(job.displayCompany)
                Status: \(job.status.rawValue)
                Job Description:
                \(job.jobDescription.isEmpty ? "Not provided" : job.jobDescription)

                Help the user with their application. Be specific, actionable, and concise.
                """
                let messages = state.chatMessages

                if state.acpConnection.aiProvider == .acpAgent && state.acpConnection.isConnected {
                    // For ACP: include system prompt context in first message
                    let contextPrefix = messages.count <= 1 ? systemPrompt + "\n\n" : ""
                    let fullMessage = contextPrefix + userText
                    return .run { send in
                        await send(.aiResponseReceived(Result {
                            try await acpClient.sendPrompt(fullMessage, messages)
                        }))
                    }
                    .cancellable(id: CancelID.aiRequest, cancelInFlight: true)
                } else {
                    let key = state.apiKey
                    return .run { send in
                        await send(.aiResponseReceived(Result {
                            try await claudeClient.chat(key, systemPrompt, messages)
                        } as Result<(String, AITokenUsage), Error>))
                    }
                    .cancellable(id: CancelID.aiRequest, cancelInFlight: true)
                }

            case .clearChat:
                state.chatMessages = []
                state.aiInput = ""
                state.aiError = nil
                state.aiTokenUsage = .zero
                return .none

            case .aiResponseReceived(.success(let (text, usage))):
                state.aiIsLoading = false
                state.chatMessages.append(ChatMessage(role: .assistant, content: text))
                state.aiTokenUsage = AITokenUsage(
                    inputTokens: state.aiTokenUsage.inputTokens + usage.inputTokens,
                    outputTokens: state.aiTokenUsage.outputTokens + usage.outputTokens
                )
                return .none

            case .aiResponseReceived(.failure(let error)):
                state.aiIsLoading = false
                state.aiError = error.localizedDescription
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
