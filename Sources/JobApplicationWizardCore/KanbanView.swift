import SwiftUI
import ComposableArchitecture

// MARK: - Main Kanban Board

public struct KanbanView: View {
    let store: StoreOf<AppFeature>
    let onDocumentDrop: (UUID, [URL]) -> Void
    var processingJobIds: Set<UUID> = []

    public init(store: StoreOf<AppFeature>, onDocumentDrop: @escaping (UUID, [URL]) -> Void = { _, _ in }, processingJobIds: Set<UUID> = []) {
        self.store = store
        self.onDocumentDrop = onDocumentDrop
        self.processingJobIds = processingJobIds
    }

    func jobsInColumn(_ status: JobStatus) -> [JobApplication] {
        store.filteredJobs
            .filter { $0.status == status }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                let visibleStatuses = store.filterStatus.map { [$0] } ?? JobStatus.allCases
                ForEach(visibleStatuses) { status in
                    KanbanRow(
                        status: status,
                        jobs: jobsInColumn(status),
                        selectedJobID: store.selectedJobID,
                        onSelect: { store.send(.selectJob($0)) },
                        onMove: { store.send(.moveJob($0, $1)) },
                        onToggleFavorite: { store.send(.toggleFavorite($0)) },
                        onDelete: { store.send(.deleteJob($0)) },
                        onDocumentDrop: onDocumentDrop,
                        processingJobIds: processingJobIds
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Kanban Row (swimlane)

struct KanbanRow: View {
    let status: JobStatus
    let jobs: [JobApplication]
    let selectedJobID: UUID?
    let onSelect: (UUID) -> Void
    let onMove: (UUID, JobStatus) -> Void
    let onToggleFavorite: (UUID) -> Void
    let onDelete: (UUID) -> Void
    var onDocumentDrop: (UUID, [URL]) -> Void = { _, _ in }
    var processingJobIds: Set<UUID> = []

    @State private var isTargeted = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Status header — fixed left column
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: status.icon)
                        .foregroundColor(status.color)
                    Text(status.rawValue)
                        .font(.headline)
                }
                Text("\(jobs.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(status.color.opacity(0.15))
                    .foregroundColor(status.color)
                    .clipShape(Capsule())
            }
            .frame(minWidth: 100, idealWidth: 130, maxWidth: 150, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.leading, 12)
            .cuttleDockable(context: .status(status))

            Rectangle()
                .fill(status.color)
                .frame(width: 2)
                .padding(.vertical, 8)

            // Cards scroll horizontally
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(jobs) { job in
                        JobCard(
                            job: job,
                            isSelected: selectedJobID == job.id,
                            onSelect: { onSelect(job.id) },
                            onMove: { onMove(job.id, $0) },
                            onToggleFavorite: { onToggleFavorite(job.id) },
                            onDelete: { onDelete(job.id) }
                        )
                        .frame(width: 240)
                        .overlay {
                            if processingJobIds.contains(job.id) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        VStack(spacing: 6) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Processing document…")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                            }
                        }
                        .cuttleDockable(context: .job(job.id))
                        .dropDestination(for: URL.self) { urls, _ in
                            guard !urls.isEmpty else { return false }
                            onDocumentDrop(job.id, urls)
                            return true
                        }
                        .draggable(job.id.uuidString) {
                            JobCard(
                                job: job,
                                isSelected: false,
                                onSelect: {},
                                onMove: { _ in },
                                onToggleFavorite: {},
                                onDelete: {}
                            )
                            .frame(width: 220)
                            .opacity(0.8)
                        }
                    }
                    if jobs.isEmpty {
                        EmptyColumnView(status: status)
                            .frame(width: 220)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isTargeted
                      ? status.color.opacity(0.08)
                      : Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isTargeted ? status.color : Color.clear, lineWidth: 2)
                )
        )
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first,
                  let id = UUID(uuidString: idString)
            else { return false }
            onMove(id, status)
            return true
        } isTargeted: { isTargeted = $0 }
    }
}

// MARK: - Job Card

struct JobCard: View {
    let job: JobApplication
    let isSelected: Bool
    let onSelect: () -> Void
    let onMove: (JobStatus) -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var showTaskPopover = false
    @State private var hoverTimer: Task<Void, Never>? = nil

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(job.displayCompany)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if job.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                    ExcitementDots(level: job.excitement)
                }

                Text(job.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !job.location.isEmpty || !job.salary.isEmpty {
                    HStack(spacing: 4) {
                        if !job.location.isEmpty {
                            Label(job.location, systemImage: "mappin.circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if !job.salary.isEmpty {
                            Spacer()
                            Text(job.salary)
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }

                if !job.labels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(job.labels.prefix(3)) { label in
                                Text(label.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(label.color.opacity(0.18))
                                    .foregroundColor(label.color)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                HStack {
                    if let applied = job.dateApplied {
                        Label(applied.relativeString, systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Label(job.dateAdded.relativeString, systemImage: "plus.circle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !job.currentTasks.isEmpty {
                        let done = job.currentTasks.filter { $0.isCompleted }.count
                        let total = job.currentTasks.count
                        let allDone = done == total
                        Label("\(done)/\(total)", systemImage: allDone ? "checkmark.circle.fill" : "checklist")
                            .font(.caption2)
                            .foregroundColor(allDone ? .green : .secondary)
                    }
                    if !job.contacts.isEmpty {
                        Label("\(job.contacts.count)", systemImage: "person.circle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? job.status.color.opacity(0.12)
                          : Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? job.status.color : (isHovered ? Color.secondary.opacity(0.3) : Color.clear),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTaskPopover, arrowEdge: .bottom) {
            TaskPopoverView(job: job)
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                hoverTimer = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    guard !Task.isCancelled else { return }
                    if !job.currentTasks.isEmpty {
                        showTaskPopover = true
                    }
                }
            } else {
                hoverTimer?.cancel()
                hoverTimer = nil
                showTaskPopover = false
            }
        }
        .contextMenu {
            Menu("Move to") {
                ForEach(JobStatus.allCases) { s in
                    if s != job.status {
                        Button { onMove(s) } label: {
                            Label(s.rawValue, systemImage: s.icon)
                        }
                    }
                }
            }
            Divider()
            Button { onToggleFavorite() } label: {
                Label(job.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: job.isFavorite ? "star.slash" : "star")
            }
            if !job.url.isEmpty, let url = URL(string: job.url) {
                Button { NSWorkspace.shared.open(url) } label: {
                    Label("Open Job URL", systemImage: "link")
                }
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Task Popover

struct TaskPopoverView: View {
    let job: JobApplication

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(job.status.rawValue) Tasks")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            ForEach(job.currentTasks) { task in
                HStack(spacing: 6) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .green : .secondary)
                        .font(.caption)
                    Text(task.title)
                        .font(.caption)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                }
            }
        }
        .padding(12)
        .frame(minWidth: 200)
    }
}

// MARK: - Excitement Dots

struct ExcitementDots: View {
    let level: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= level ? Color.orange : Color.secondary.opacity(0.2))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

// MARK: - Empty Column Placeholder

struct EmptyColumnView: View {
    let status: JobStatus
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.largeTitle)
                .foregroundColor(status.color.opacity(0.3))
            Text("No \(status.rawValue) jobs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
