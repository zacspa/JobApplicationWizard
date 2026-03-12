import ComposableArchitecture
import Foundation

@Reducer
struct AddJobFeature {
    @ObservableState
    struct State: Equatable {
        var company = ""
        var title = ""
        var url = ""
        var location = ""
        var salary = ""
        var status: JobStatus = .wishlist
        var excitement: Int = 3
        var jobDescription = ""
        var notes = ""
        var selectedLabelNames: Set<String> = []

        var canSave: Bool { !company.isEmpty || !title.isEmpty }

        func buildJob() -> JobApplication {
            var job = JobApplication()
            job.company = company
            job.title = title
            job.url = url
            job.location = location
            job.salary = salary
            job.status = status
            job.excitement = excitement
            job.jobDescription = jobDescription
            job.notes = notes
            job.labels = JobLabel.presets.filter { selectedLabelNames.contains($0.name) }
            if status == .applied { job.dateApplied = Date() }
            return job
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toggleLabel(String)
        case setExcitement(Int)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case save(JobApplication)
            case cancel
        }
    }

    var body: some ReducerOf<Self> {
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
