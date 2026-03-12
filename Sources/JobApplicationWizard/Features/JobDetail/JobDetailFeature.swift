import ComposableArchitecture
import Foundation
import AppKit

@Reducer
struct JobDetailFeature {
    @ObservableState
    struct State: Equatable {
        // Source of truth
        var job: JobApplication

        // Flat editable fields (synced to/from job on BindingReducer changes)
        var company: String
        var title: String
        var location: String
        var salary: String
        var url: String
        var notes: String
        var jobDescription: String
        var resumeUsed: String
        var labels: [JobLabel]
        var contacts: [Contact]
        var interviews: [InterviewRound]

        // UI state
        var selectedTab: Tab = .overview
        var showDeleteConfirm: Bool = false

        // PDF state
        var isGeneratingPDF: Bool = false
        var pdfError: String? = nil
        var showCopied: Bool = false

        // AI state
        var aiSelectedAction: AIAction = .chat
        var aiInput: String = ""
        var chatMessages: [ChatMessage] = []
        var aiIsLoading: Bool = false
        var aiError: String? = nil
        var apiKey: String

        enum Tab: String, CaseIterable, Equatable {
            case overview = "Overview"
            case description = "Description"
            case notes = "Notes"
            case contacts = "Contacts"
            case interviews = "Interviews"
            case ai = "AI"
        }

        init(job: JobApplication, apiKey: String = "") {
            self.job = job
            self.company = job.company
            self.title = job.title
            self.location = job.location
            self.salary = job.salary
            self.url = job.url
            self.notes = job.notes
            self.jobDescription = job.jobDescription
            self.resumeUsed = job.resumeUsed
            self.labels = job.labels
            self.contacts = job.contacts
            self.interviews = job.interviews
            self.apiKey = apiKey
        }

        // Build updated job from current flat fields
        mutating func syncJobFromFields() {
            job.company = company
            job.title = title
            job.location = location
            job.salary = salary
            job.url = url
            job.notes = notes
            job.jobDescription = jobDescription
            job.resumeUsed = resumeUsed
            job.labels = labels
            job.contacts = contacts
            job.interviews = interviews
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case selectTab(State.Tab)
        case setExcitement(Int)
        case toggleFavorite
        case moveJob(JobStatus)
        case markApplied
        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
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
        case aiResponseReceived(Result<String, Error>)
        // Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            case jobUpdated(JobApplication)
            case jobDeleted(UUID)
        }
    }

    @Dependency(\.pdfClient) var pdfClient
    @Dependency(\.claudeClient) var claudeClient

    private enum CancelID { case aiRequest }

    var body: some ReducerOf<Self> {
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

                let key = state.apiKey
                let job = state.job
                let systemPrompt = """
                You are an expert career coach integrated into a job application tracker.

                Job: \(job.displayTitle) at \(job.displayCompany)
                Status: \(job.status.rawValue)
                Job Description:
                \(job.jobDescription.isEmpty ? "Not provided" : job.jobDescription)

                Help the user with their application. Be specific, actionable, and concise.
                """
                let messages = state.chatMessages
                return .run { send in
                    await send(.aiResponseReceived(Result {
                        try await claudeClient.chat(key, systemPrompt, messages)
                    }))
                }
                .cancellable(id: CancelID.aiRequest, cancelInFlight: true)

            case .clearChat:
                state.chatMessages = []
                state.aiInput = ""
                state.aiError = nil
                return .none

            case .aiResponseReceived(.success(let text)):
                state.aiIsLoading = false
                state.chatMessages.append(ChatMessage(role: .assistant, content: text))
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
