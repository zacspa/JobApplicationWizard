import SwiftUI
import ComposableArchitecture
import JobApplicationShared

struct PipelineView: View {
    @Bindable var store: StoreOf<iOSAppFeature>

    private let orderedStatuses: [JobStatus] = [
        .wishlist, .applied, .phoneScreen, .interview, .offer, .rejected, .withdrawn
    ]

    var body: some View {
        NavigationStack(path: $store.path) {
            Group {
                if store.isLoading {
                    ProgressView("Loading jobs...")
                } else if store.filteredJobs.isEmpty {
                    ContentUnavailableView(
                        "No Jobs Yet",
                        systemImage: "briefcase",
                        description: Text("Add a job from the Add Job tab to get started.")
                    )
                } else {
                    jobList
                }
            }
            .navigationTitle("Pipeline")
            .searchable(text: $store.searchQuery, prompt: "Search jobs...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .navigationDestination(for: UUID.self) { jobId in
                JobDetailViewiOS(store: store, jobId: jobId)
            }
        }
    }

    private var jobList: some View {
        List {
            ForEach(orderedStatuses, id: \.self) { status in
                let jobs = store.filteredJobs.filter { $0.status == status }
                if !jobs.isEmpty {
                    Section {
                        ForEach(jobs) { job in
                            NavigationLink(value: job.id) {
                                JobRow(job: job)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.send(.deleteJob(job.id))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    store.send(.toggleFavorite(job.id))
                                } label: {
                                    Label(
                                        job.isFavorite ? "Unfavorite" : "Favorite",
                                        systemImage: job.isFavorite ? "star.slash" : "star.fill"
                                    )
                                }
                                .tint(.yellow)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: status.icon)
                                .foregroundStyle(status.color)
                            Text(status.rawValue)
                            Spacer()
                            Text("\(jobs.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Button {
                store.send(.filterStatusChanged(nil))
            } label: {
                if store.filterStatus == nil {
                    Label("All", systemImage: "checkmark")
                } else {
                    Text("All")
                }
            }
            Divider()
            ForEach(orderedStatuses, id: \.self) { status in
                Button {
                    store.send(.filterStatusChanged(status))
                } label: {
                    if store.filterStatus == status {
                        Label(status.rawValue, systemImage: "checkmark")
                    } else {
                        Label(status.rawValue, systemImage: status.icon)
                    }
                }
            }
        } label: {
            Image(systemName: store.filterStatus != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
}
