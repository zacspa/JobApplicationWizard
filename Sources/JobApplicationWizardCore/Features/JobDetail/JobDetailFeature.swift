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

        // References needed for job creation in AppFeature
        public var apiKey: String
        public var userProfile: UserProfile

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
        // Delegate
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case jobUpdated(JobApplication)
            case jobDeleted(UUID)
        }
    }

    @Dependency(\.pdfClient) var pdfClient

    public init() {}

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

            case .delegate:
                return .none
            }
        }
    }
}
