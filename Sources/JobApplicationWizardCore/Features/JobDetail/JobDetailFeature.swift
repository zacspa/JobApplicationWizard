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
        public var aiPanelOpen: Bool = false
        public var aiInput: String = ""
        public var chatMessages: [ChatMessage] = []
        public var aiIsLoading: Bool = false
        public var aiError: String? = nil
        public var acpSentSystemPrompt: Bool = false
        public var apiKey: String
        public var userProfile: UserProfile
        public var aiTokenUsage: AITokenUsage = .zero
        #if DEBUG
        public var aiMockMode: Bool = false
        #endif
        @SharedReader(.inMemory("acpConnection")) public var acpConnection = ACPConnectionState()

        public enum Tab: String, CaseIterable, Equatable {
            case overview = "Overview"
            case description = "Description"
            case notes = "Notes"
            case contacts = "Contacts"
            case interviews = "Interviews"

            public var label: String {
                switch self {
                case .description: return "JD"
                default: return rawValue
                }
            }

            public var icon: String {
                switch self {
                case .overview: return "info.circle"
                case .description: return "doc.text"
                case .notes: return "note.text"
                case .contacts: return "person.2"
                case .interviews: return "calendar.badge.clock"
                }
            }
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
            self.chatMessages = job.chatHistory
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
            job.chatHistory = chatMessages
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
        case toggleAIPanel
        case openAIPanelWithPrompt(String)
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

            case .toggleAIPanel:
                state.aiPanelOpen.toggle()
                return .none

            case .openAIPanelWithPrompt(let prompt):
                state.aiPanelOpen = true
                state.aiInput = prompt
                return .none

            case .sendMessage:
                let rawInput = state.aiInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawInput.isEmpty else { return .none }

                state.chatMessages.append(ChatMessage(role: .user, content: rawInput))
                state.aiInput = ""
                state.aiIsLoading = true
                state.aiError = nil

                #if DEBUG
                if state.aiMockMode {
                    return .run { send in
                        try await Task.sleep(nanoseconds: UInt64.random(in: 3_000_000_000...6_000_000_000))
                        let mockResponses = [
                            "That's a great question! Based on the job description, I'd recommend highlighting your experience with cross-functional collaboration and any metrics-driven results.",
                            "Here are a few talking points you could use:\n\n1. Your background aligns well with the role requirements\n2. Consider emphasizing relevant project outcomes\n3. The company culture seems like a strong fit",
                            "I've reviewed the details. This looks like a solid opportunity. Would you like me to help you draft a tailored response?",
                            "Good thinking. Let me break this down:\n\n- **Strengths**: Your skills match several key requirements\n- **Gaps**: Consider brushing up on any unfamiliar tools listed\n- **Next step**: Prepare 2-3 stories using the STAR framework",
                        ]
                        let reply = mockResponses[Int.random(in: 0..<mockResponses.count)]
                        await send(.aiResponseReceived(.success((reply, .zero))))
                    }
                    .cancellable(id: CancelID.aiRequest, cancelInFlight: true)
                }
                #endif

                let systemPrompt = Self.buildSystemPrompt(
                    job: state.job,
                    profile: state.userProfile,
                    activeTab: state.selectedTab,
                    chatHistory: state.chatMessages
                )
                let messages = state.chatMessages

                if state.acpConnection.aiProvider == .acpAgent && state.acpConnection.isConnected {
                    // ACP sessions maintain conversation history server-side, so we only
                    // need to send the current message. System prompt context is prepended
                    // to the first message of each session to establish job/profile context.
                    let contextPrefix = state.acpSentSystemPrompt ? "" : systemPrompt + "\n\n"
                    state.acpSentSystemPrompt = true
                    let fullMessage = contextPrefix + rawInput
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
                state.acpSentSystemPrompt = false
                state.syncJobFromFields()
                return .send(.delegate(.jobUpdated(state.job)))

            case .aiResponseReceived(.success(let (text, usage))):
                state.aiIsLoading = false
                state.chatMessages.append(ChatMessage(role: .assistant, content: text))
                state.aiTokenUsage = AITokenUsage(
                    inputTokens: state.aiTokenUsage.inputTokens + usage.inputTokens,
                    outputTokens: state.aiTokenUsage.outputTokens + usage.outputTokens
                )
                state.syncJobFromFields()
                return .send(.delegate(.jobUpdated(state.job)))

            case .aiResponseReceived(.failure(let error)):
                state.aiIsLoading = false
                state.aiError = "\(type(of: error)): \(error.localizedDescription)"
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// Builds the system prompt for AI chat, incorporating the user profile, job context,
    /// active tab, and recent chat history for continuity.
    public static func buildSystemPrompt(
        job: JobApplication,
        profile: UserProfile,
        activeTab: State.Tab = .overview,
        chatHistory: [ChatMessage] = []
    ) -> String {
        var sections: [String] = []

        sections.append("You are an expert career coach integrated into a job application tracker.")

        // Candidate profile
        if !profile.name.isEmpty || !profile.resume.isEmpty {
            var lines: [String] = ["About the candidate:"]
            if !profile.name.isEmpty { lines.append("Name: \(profile.name)") }
            if !profile.currentTitle.isEmpty { lines.append("Current Title: \(profile.currentTitle)") }
            if !profile.location.isEmpty { lines.append("Location: \(profile.location)") }
            if !profile.skills.isEmpty { lines.append("Skills: \(profile.skills.joined(separator: ", "))") }
            if !profile.targetRoles.isEmpty { lines.append("Target Roles: \(profile.targetRoles.joined(separator: ", "))") }
            if !profile.preferredSalary.isEmpty { lines.append("Preferred Salary: \(profile.preferredSalary)") }
            lines.append("Work Preference: \(profile.workPreference.rawValue)")
            if !profile.summary.isEmpty { lines.append("Summary: \(profile.summary)") }
            if !profile.resume.isEmpty { lines.append("Resume:\n\(profile.resume)") }
            sections.append(lines.joined(separator: "\n"))
        }

        // Job details
        var jobLines: [String] = [
            "Target Job: \(job.displayTitle) at \(job.displayCompany)",
            "Status: \(job.status.rawValue)",
        ]
        if !job.location.isEmpty { jobLines.append("Location: \(job.location)") }
        if !job.salary.isEmpty { jobLines.append("Salary: \(job.salary)") }
        if !job.labels.isEmpty { jobLines.append("Labels: \(job.labels.map(\.name).joined(separator: ", "))") }
        if job.excitement != 3 { jobLines.append("Excitement: \(job.excitement)/5") }
        if !job.resumeUsed.isEmpty { jobLines.append("Resume Version: \(job.resumeUsed)") }
        sections.append(jobLines.joined(separator: "\n"))

        // Job description
        sections.append("Job Description:\n\(job.jobDescription.isEmpty ? "Not provided" : job.jobDescription)")

        // Notes
        if !job.noteCards.isEmpty {
            let noteLines = job.noteCards.map { note in
                let body = note.body.count > 500 ? String(note.body.prefix(500)) + "..." : note.body
                let title = note.title.isEmpty ? "Untitled" : note.title
                return "- \(title): \(body)"
            }
            sections.append("Notes:\n\(noteLines.joined(separator: "\n"))")
        }

        // Contacts
        if !job.contacts.isEmpty {
            let contactLines = job.contacts.map { c in
                let titlePart = c.title.isEmpty ? "" : " (\(c.title))"
                let notesPart = c.notes.isEmpty ? "" : " \u{2014} \(c.notes)"
                return "- \(c.name)\(titlePart)\(notesPart)"
            }
            sections.append("Contacts:\n\(contactLines.joined(separator: "\n"))")
        }

        // Interview rounds
        if !job.interviews.isEmpty {
            let interviewLines = job.interviews.map { iv in
                var parts = "- Round \(iv.round): \(iv.type.isEmpty ? "TBD" : iv.type)"
                if let date = iv.date { parts += ", \(date.relativeString)" }
                if !iv.interviewers.isEmpty { parts += ", Interviewers: \(iv.interviewers)" }
                if !iv.notes.isEmpty { parts += ", Notes: \(iv.notes)" }
                if iv.completed { parts += " (completed)" }
                return parts
            }
            sections.append("Interview Rounds:\n\(interviewLines.joined(separator: "\n"))")
        }

        // Recent activity timeline
        var timeline: [String] = []
        timeline.append("- Added: \(job.dateAdded.relativeString)")
        if let applied = job.dateApplied {
            timeline.append("- Applied: \(applied.relativeString)")
        } else {
            timeline.append("- Applied: Not yet")
        }
        let now = Date()
        let upcoming = job.interviews
            .filter { $0.date != nil && $0.date! > now && !$0.completed }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        for iv in upcoming.prefix(3) {
            let typeLabel = iv.type.isEmpty ? "Round \(iv.round)" : "Round \(iv.round) (\(iv.type))"
            timeline.append("- \(typeLabel) scheduled \(iv.date!.relativeString)")
        }
        if let recentNote = job.noteCards.max(by: { $0.updatedAt < $1.updatedAt }),
           !recentNote.title.isEmpty {
            timeline.append("- Note '\(recentNote.title)' updated \(recentNote.updatedAt.relativeString)")
        }
        sections.append("Recent Activity:\n\(timeline.joined(separator: "\n"))")

        // Active tab context
        sections.append("The user is currently viewing the \(activeTab.rawValue) tab.")

        // Chat history tail for continuity
        if !chatHistory.isEmpty {
            let tail = chatHistory.suffix(6)
            let recap = tail.map { msg in
                let role = msg.role == .user ? "User" : "Assistant"
                let content = msg.content.count > 300 ? String(msg.content.prefix(300)) + "..." : msg.content
                return "\(role): \(content)"
            }
            sections.append("Previous conversation (\(chatHistory.count) messages):\n\(recap.joined(separator: "\n"))")
        }

        sections.append("Help the user with their application. Be specific, actionable, and concise.\nReference the data above when relevant; don't ask the user to repeat information they've already entered.")

        return sections.joined(separator: "\n\n")
    }
}
