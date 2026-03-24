import SwiftUI
import ComposableArchitecture

public struct ListView: View {
    let store: StoreOf<AppFeature>
    let onDocumentDrop: (UUID, [URL]) -> Void

    @State
    private var sortOrder: [KeyPathComparator<JobApplication>] = [KeyPathComparator(\.dateAdded, order: .reverse)]

    public init(store: StoreOf<AppFeature>, onDocumentDrop: @escaping (UUID, [URL]) -> Void = { _, _ in }) {
        self.store = store
        self.onDocumentDrop = onDocumentDrop
    }

    var sortedJobs: [JobApplication] {
        store.filteredJobs.sorted(using: sortOrder)
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
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Color.textSecondary)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Color.controlBackground)

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
                Table(sortedJobs, selection: selectionBinding, sortOrder: $sortOrder) {
                    TableColumn("Company / Role", value: \.company) { job in
                        VStack(alignment: .leading, spacing: 2) {
                            // Note: cuttleDockable is applied to the whole VStack below
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: job.status.icon)
                                    .foregroundColor(job.status.color)
                                    .font(DS.Typography.subheadline)
                                Text(job.displayCompany)
                                    .fontWeight(.semibold)
                                if job.isFavorite {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(DS.Typography.caption2)
                                }
                                ForEach(job.labels.prefix(2)) { label in
                                    Text(label.name)
                                        .font(DS.Typography.micro)
                                        .padding(.horizontal, DS.Spacing.xs).padding(.vertical, 1)
                                        .background(label.color.opacity(DS.Color.Opacity.tint))
                                        .foregroundColor(label.color)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(job.displayTitle)
                                .font(DS.Typography.subheadline)
                                .foregroundColor(DS.Color.textSecondary)
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                if let badge = interviewCountdownInfo(rounds: job.interviews, now: context.date) {
                                    Label(badge.text, systemImage: "calendar.badge.clock")
                                        .font(DS.Typography.caption2)
                                        .foregroundColor(badge.color)
                                        .italic(badge.isItalic)
                                }
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

                    TableColumn("Excitement", value: \.excitement) { job in
                        ExcitementDots(level: job.excitement)
                    }
                    .width(70)

                    TableColumn("Status", value: \.status) { job in
                        Text(job.status.rawValue)
                            .font(DS.Typography.caption)
                            .padding(.horizontal, DS.Spacing.sm).padding(.vertical, DS.Spacing.xxxs)
                            .background(job.status.color.opacity(DS.Color.Opacity.wash))
                            .foregroundColor(job.status.color)
                            .clipShape(Capsule())
                    }
                    .width(110)

                    TableColumn("Location", value: \.location) { job in
                        Text(job.location.isEmpty ? "—" : job.location)
                            .foregroundColor(job.location.isEmpty ? Color.secondary.opacity(0.3) : .secondary)
                            .lineLimit(1)
                    }
                    .width(90)

                    TableColumn("Salary", value: \.salary) { job in
                        Text(job.salary.isEmpty ? "—" : job.salary)
                            .foregroundColor(job.salary.isEmpty ? Color.secondary.opacity(0.3) : .green)
                            .lineLimit(1)
                    }
                    .width(160)

                    TableColumn("Date Added", value: \.dateAdded) { job in
                        Text(job.dateAdded.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(DS.Color.textSecondary)
                    }
                    .width(90)
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
