import SwiftUI
import ComposableArchitecture

public struct ListView: View {
    let store: StoreOf<AppFeature>
    let onDocumentDrop: (UUID, [URL]) -> Void
    @State private var sortOrder = SortOrder.dateDesc

    public init(store: StoreOf<AppFeature>, onDocumentDrop: @escaping (UUID, [URL]) -> Void = { _, _ in }) {
        self.store = store
        self.onDocumentDrop = onDocumentDrop
    }

    enum SortOrder: String, CaseIterable {
        case dateDesc = "Newest First"
        case dateAsc  = "Oldest First"
        case company  = "Company A–Z"
        case excitement = "Most Excited"
    }

    var sortedJobs: [JobApplication] {
        let base = store.filteredJobs
        switch sortOrder {
        case .dateDesc:   return base.sorted { $0.dateAdded > $1.dateAdded }
        case .dateAsc:    return base.sorted { $0.dateAdded < $1.dateAdded }
        case .company:    return base.sorted { $0.company < $1.company }
        case .excitement: return base.sorted { $0.excitement > $1.excitement }
        }
    }

    var selectionBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedJobID },
            set: { store.send(.selectJob($0)) }
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(sortedJobs.count) jobs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .font(.caption)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if sortedJobs.isEmpty {
                ContentUnavailableView(
                    "No Jobs Found",
                    systemImage: "magnifyingglass",
                    description: Text(store.searchQuery.isEmpty
                        ? "Add your first job application"
                        : "Try a different search")
                )
            } else {
                Table(sortedJobs, selection: selectionBinding) {
                    TableColumn("Company / Role") { job in
                        VStack(alignment: .leading, spacing: 2) {
                            // Note: cuttleDockable is applied to the whole VStack below
                            HStack(spacing: 5) {
                                Image(systemName: job.status.icon)
                                    .foregroundColor(job.status.color)
                                    .font(.subheadline)
                                Text(job.displayCompany)
                                    .fontWeight(.semibold)
                                if job.isFavorite {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption2)
                                }
                                ForEach(job.labels.prefix(2)) { label in
                                    Text(label.name)
                                        .font(.system(size: 9))
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(label.color.opacity(0.15))
                                        .foregroundColor(label.color)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(job.displayTitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let badge = interviewCountdownInfo(rounds: job.interviews) {
                                Label(badge.text, systemImage: "calendar.badge.clock")
                                    .font(.caption2)
                                    .foregroundColor(badge.color)
                                    .italic(badge.isItalic)
                            }
                        }
                        .padding(.vertical, 2)
                        .cuttleDockable(context: .job(job.id))
                        .dropDestination(for: URL.self) { urls, _ in
                            guard !urls.isEmpty else { return false }
                            onDocumentDrop(job.id, urls)
                            return true
                        }
                    }

                    TableColumn("Excitement") { job in
                        ExcitementDots(level: job.excitement)
                    }
                    .width(70)

                    TableColumn("Status") { job in
                        Text(job.status.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(job.status.color.opacity(0.12))
                            .foregroundColor(job.status.color)
                            .clipShape(Capsule())
                    }
                    .width(110)

                    TableColumn("Location") { job in
                        Text(job.location.isEmpty ? "—" : job.location)
                            .foregroundColor(job.location.isEmpty ? Color.secondary.opacity(0.3) : .secondary)
                            .lineLimit(1)
                    }
                    .width(90)

                    TableColumn("Salary") { job in
                        Text(job.salary.isEmpty ? "—" : job.salary)
                            .foregroundColor(job.salary.isEmpty ? Color.secondary.opacity(0.3) : .green)
                            .lineLimit(1)
                    }
                    .width(160)
                }
                .contextMenu(forSelectionType: UUID.self) { ids in
                    if let id = ids.first,
                       let job = store.filteredJobs.first(where: { $0.id == id }) {
                        Menu("Move to") {
                            ForEach(JobStatus.allCases) { s in
                                if s != job.status {
                                    Button { store.send(.moveJob(id, s)) } label: {
                                        Label(s.rawValue, systemImage: s.icon)
                                    }
                                }
                            }
                        }
                        Divider()
                        Button(role: .destructive) { store.send(.deleteJob(id)) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}
