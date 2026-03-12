import ComposableArchitecture
import Foundation

@Reducer
public struct AddJobFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var company = ""
        public var title = ""
        public var url = ""
        public var location = ""
        public var salary = ""
        public var status: JobStatus = .wishlist
        public var excitement: Int = 3
        public var jobDescription = ""
        public var selectedLabelNames: Set<String> = []

        public var canSave: Bool { !company.isEmpty || !title.isEmpty }

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
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case save(JobApplication)
            case cancel
        }
    }

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
            case .delegate:
                return .none
            }
        }
    }
}
