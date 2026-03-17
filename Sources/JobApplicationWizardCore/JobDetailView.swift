import SwiftUI
import ComposableArchitecture

// MARK: - Job Detail Panel

public struct JobDetailView: View {
    @Bindable var store: StoreOf<JobDetailFeature>

    public init(store: StoreOf<JobDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabBar
            Divider()
            tabContent
                .frame(minWidth: 460)
        }
        .alert("Delete Application", isPresented: Binding(
            get: { store.showDeleteConfirm },
            set: { if !$0 { store.send(.deleteCancelled) } }
        )) {
            Button("Delete", role: .destructive) { store.send(.deleteConfirmed) }
            Button("Cancel", role: .cancel) { store.send(.deleteCancelled) }
        } message: {
            Text("Delete \(store.job.displayTitle) at \(store.job.displayCompany)? This cannot be undone.")
        }
        .alert("Incomplete Tasks", isPresented: Binding(
            get: { store.showIncompleteTasksAlert },
            set: { if !$0 { store.send(.moveJobAlertCancel) } }
        )) {
            Button("Continue Anyway", role: .destructive) { store.send(.moveJobAlertContinue) }
            Button("Cancel", role: .cancel) { store.send(.moveJobAlertCancel) }
        } message: {
            Text("You have incomplete tasks for this stage. Move anyway?")
        }
    }

    var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(JobDetailFeature.State.Tab.allCases, id: \.self) { tab in
                    Button { store.send(.selectTab(tab)) } label: {
                        Label(tab.label, systemImage: tab.icon)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(store.selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                            .foregroundColor(store.selectedTab == tab ? .accentColor : .secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    var tabContent: some View {
        switch store.selectedTab {
        case .overview: OverviewTab(store: store)
        case .description: DescriptionTab(store: store)
        case .notes: NotesTab(store: store)
        case .contacts: ContactsTab(store: store)
        case .interviews: InterviewsTab(store: store)
        case .documents: DocumentsTab(store: store)
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.job.displayCompany)
                        .font(.title3).fontWeight(.bold)
                        .lineLimit(2)
                    Text(store.job.displayTitle)
                        .font(.subheadline).foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button { store.send(.toggleFavorite) } label: {
                        Image(systemName: store.job.isFavorite ? "star.fill" : "star")
                            .foregroundColor(store.job.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)

                    if !store.job.url.isEmpty, let url = URL(string: store.job.url) {
                        Button { NSWorkspace.shared.open(url) } label: {
                            Image(systemName: "link.circle").foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    Menu {
                        ForEach(JobStatus.allCases) { s in
                            Button { store.send(.moveJobRequested(s)) } label: {
                                Label(s.rawValue, systemImage: s.icon)
                            }
                        }
                        Divider()
                        Button(role: .destructive) { store.send(.deleteTapped) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Label(store.job.status.rawValue, systemImage: store.job.status.icon)
                    .font(.footnote).fontWeight(.semibold)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(store.job.status.color.opacity(0.15))
                    .foregroundColor(store.job.status.color)
                    .clipShape(Capsule())

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= store.job.excitement ? "star.fill" : "star")
                            .font(.footnote).foregroundColor(.orange)
                            .onTapGesture { store.send(.setExcitement(i)) }
                    }
                }
            }

            if !store.job.labels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(store.job.labels) { label in
                            HStack(spacing: 3) {
                                Circle().fill(label.color).frame(width: 6, height: 6)
                                Text(label.name).font(.footnote)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(label.color.opacity(0.12)).clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    @Bindable var store: StoreOf<JobDetailFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Application Details") {
                    VStack(spacing: 0) {
                        DetailRow(icon: "building.2", label: "Company") {
                            TextField("Company name", text: $store.company).textFieldStyle(.plain)
                        }
                        Divider()
                        DetailRow(icon: "briefcase", label: "Title") {
                            TextField("Job title", text: $store.title).textFieldStyle(.plain)
                        }
                        Divider()
                        DetailRow(icon: "mappin.circle", label: "Location") {
                            TextField("City, State / Remote", text: $store.location).textFieldStyle(.plain)
                        }
                        Divider()
                        DetailRow(icon: "dollarsign.circle", label: "Salary") {
                            TextField("e.g. $120k-150k", text: $store.salary).textFieldStyle(.plain)
                        }
                        Divider()
                        DetailRow(icon: "link", label: "URL") {
                            TextField("https://...", text: $store.url).textFieldStyle(.plain)
                        }
                    }
                }

                GroupBox("Timeline") {
                    let allLabels: [String] = ["Added", "Applied"] + store.job.interviews.map {
                        $0.type.isEmpty ? "Round \($0.round)" : "Round \($0.round) · \($0.type)"
                    }
                    let longestLabel = allLabels.max(by: { $0.count < $1.count }) ?? ""
                    // Approximate width: ~7.5pt per character for subheadline
                    let labelWidth = max(80, CGFloat(longestLabel.count) * 7.5 + 8)

                    VStack(spacing: 0) {
                        timelineRow(
                            icon: "plus.circle",
                            iconColor: .secondary,
                            label: "Added",
                            date: store.job.dateAdded.formatted(date: .abbreviated, time: .omitted),
                            labelWidth: labelWidth
                        )
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("Applied")
                                .font(.subheadline).foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(width: labelWidth, alignment: .leading)
                            if let applied = store.job.dateApplied {
                                Text(applied.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                            } else {
                                Text("Not yet applied")
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            if store.job.dateApplied == nil {
                                Button("Mark Applied") { store.send(.markApplied) }
                                    .font(.subheadline).buttonStyle(.bordered).controlSize(.mini)
                            }
                        }
                        .padding(.vertical, 7).padding(.horizontal, 8)

                        ForEach(store.job.interviews.sorted(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) })) { interview in
                            Divider()
                            timelineRow(
                                icon: interview.completed ? "checkmark.circle.fill" : "person.line.dotted.person",
                                iconColor: interview.completed ? .green : .secondary,
                                label: interview.type.isEmpty
                                    ? "Round \(interview.round)"
                                    : "Round \(interview.round) · \(interview.type)",
                                date: interview.date?.formatted(date: .abbreviated, time: .omitted),
                                labelWidth: labelWidth
                            )
                        }
                    }
                }

                GroupBox("Resume & Documents") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Resume Version", systemImage: "doc.fill")
                                .font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                        }
                        TextField("e.g. resume_v3_tailored.pdf", text: $store.resumeUsed)
                            .textFieldStyle(.roundedBorder).font(.subheadline)
                    }
                    .padding(4)
                }

                GroupBox("Labels") {
                    LabelsEditor(labels: $store.labels).padding(4)
                }
            }
            .padding(16)
        }
    }

    private func timelineRow(icon: String, iconColor: Color, label: String, date: String?, labelWidth: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            Text(label)
                .font(.subheadline).foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
            if let date {
                Text(date).font(.subheadline)
            }
            Spacer()
        }
        .padding(.vertical, 7).padding(.horizontal, 8)
    }
}

// MARK: - Task Row

struct TaskRowView: View {
    let task: SubTask
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            Text(task.title)
                .font(.subheadline)
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
            Spacer()
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Detail Row helper

struct DetailRow<Content: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline).foregroundColor(.secondary)
                .frame(minWidth: 80, idealWidth: 110, maxWidth: 110, alignment: .leading)
            content().font(.body)
        }
        .padding(.vertical, 7).padding(.horizontal, 8)
    }
}

// MARK: - Labels Editor

struct LabelsEditor: View {
    @Binding var labels: [JobLabel]
    @State private var customName = ""
    @State private var customColor = Color.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6) {
                ForEach(labels) { label in
                    HStack(spacing: 3) {
                        Text(label.name).font(.footnote)
                        Button {
                            labels.removeAll { $0.id == label.id }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(label.color.opacity(0.15)).foregroundColor(label.color)
                    .clipShape(Capsule())
                }
            }

            Text("Quick add:").font(.footnote).foregroundColor(.secondary)
            FlowLayout(spacing: 4) {
                ForEach(JobLabel.presets.filter { p in !labels.contains { $0.name == p.name } }) { preset in
                    Button { labels.append(preset) } label: {
                        Text("+ \(preset.name)")
                            .font(.footnote).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1)).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ColorPicker("Color", selection: $customColor)
                    .labelsHidden()
                    .frame(width: 32, height: 32)
                    .fixedSize()
                TextField("Custom label...", text: $customName)
                    .textFieldStyle(.roundedBorder)
                    .font(.footnote)
                Button("Add") {
                    guard !customName.isEmpty else { return }
                    labels.append(JobLabel(name: customName, colorHex: customColor.hexString))
                    customName = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(customName.isEmpty)
            }
        }
    }
}

// MARK: - Description Tab

struct DescriptionTab: View {
    @Bindable var store: StoreOf<JobDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Paste the full job description here before it gets taken down!")
                    .font(.footnote).foregroundColor(.secondary)
                Spacer()

                if store.job.hasPDF {
                    Button { store.send(.viewPDFTapped) } label: {
                        Label("View PDF", systemImage: "doc.fill").font(.footnote)
                    }
                    .buttonStyle(.bordered).controlSize(.mini)
                }

                if !store.jobDescription.isEmpty {
                    Button { store.send(.savePDFTapped) } label: {
                        if store.isGeneratingPDF {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.mini)
                                Text("Saving…").font(.footnote)
                            }
                        } else {
                            Label("Save PDF", systemImage: "square.and.arrow.down").font(.footnote)
                        }
                    }
                    .buttonStyle(.bordered).controlSize(.mini).disabled(store.isGeneratingPDF)

                    Button { store.send(.printTapped) } label: {
                        Label("Print", systemImage: "printer").font(.footnote)
                    }
                    .buttonStyle(.bordered).controlSize(.mini)

                    Button { store.send(.copyDescriptionTapped) } label: {
                        Label(store.showCopied ? "Copied!" : "Copy",
                              systemImage: store.showCopied ? "checkmark" : "doc.on.doc")
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered).controlSize(.mini)

                    Text("\(store.jobDescription.wordCount) words")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            if let err = store.pdfError {
                Text(err).font(.footnote).foregroundColor(.red)
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
            }

            Divider()

            TextEditor(text: $store.jobDescription)
                .font(.system(.body, design: .monospaced))
                .padding(12)
        }
    }
}

// MARK: - Notes Tab

struct NotesTab: View {
    @Bindable var store: StoreOf<JobDetailFeature>
    @State private var selectedNoteID: UUID?

    static let cardColors: [Color] = [
        Color(red: 1.0, green: 0.87, blue: 0.8),   // peach
        Color(red: 0.8, green: 0.92, blue: 1.0),   // sky blue
        Color(red: 0.85, green: 1.0, blue: 0.88),  // mint
        Color(red: 0.95, green: 0.85, blue: 1.0),  // lavender
        Color(red: 1.0, green: 0.95, blue: 0.78),  // butter
        Color(red: 1.0, green: 0.82, blue: 0.88),  // rose
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TasksSectionView(store: store)
                NotesSectionView(
                    store: store,
                    cardColors: NotesTab.cardColors,
                    selectedNoteID: $selectedNoteID
                )
            }
            .padding(16)
        }
    }
}

// MARK: - Tasks Section (grouped by status phase)

struct TasksSectionView: View {
    @Bindable var store: StoreOf<JobDetailFeature>

    /// Statuses that have tasks, with the current status always first
    private var statusesWithTasks: [JobStatus] {
        let current = store.job.status
        var statuses = JobStatus.allCases.filter { status in
            store.job.tasks.contains { $0.forStatus == status }
        }
        // Always include current status so user can add tasks even if none exist yet
        if !statuses.contains(current) {
            statuses.append(current)
        }
        // Sort: current status first, then by allCases order
        statuses.sort { a, b in
            if a == current { return true }
            if b == current { return false }
            return (JobStatus.allCases.firstIndex(of: a) ?? 0) < (JobStatus.allCases.firstIndex(of: b) ?? 0)
        }
        return statuses
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                let totalRemaining = store.job.tasks.filter { !$0.isCompleted }.count
                Text(totalRemaining > 0 ? "Tasks (\(totalRemaining) remaining)" : "Tasks")
                    .font(.headline)
                Spacer()
                if !store.isAddingTask {
                    Button { store.send(.addTaskTapped) } label: {
                        Label("Add Task", systemImage: "plus").font(.footnote)
                    }
                    .buttonStyle(.bordered).controlSize(.mini)
                }
            }
            .padding(.bottom, 10)

            // Add task UI (adds to current status)
            if store.isAddingTask {
                VStack(alignment: .leading, spacing: 8) {
                    let suggestions = store.job.status.suggestedTaskTitles.filter { s in
                        !store.job.tasks.contains { $0.title == s && $0.forStatus == store.job.status }
                    }
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button { store.send(.addSuggestedTask(suggestion)) } label: {
                                        Text("+ \(suggestion)")
                                            .font(.footnote)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor.opacity(0.1))
                                            .foregroundColor(.accentColor)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    HStack {
                        TextField("Task title...", text: Binding(
                            get: { store.newTaskText },
                            set: { store.send(.newTaskTextChanged($0)) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                        .onSubmit { store.send(.saveNewTask) }
                        Button("Save") { store.send(.saveNewTask) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(store.newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Cancel") { store.send(.cancelNewTask) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                .padding(.bottom, 8)
            }

            // Grouped by status
            ForEach(statusesWithTasks) { status in
                let tasksForStatus = store.job.tasks.filter { $0.forStatus == status }
                let isCurrent = status == store.job.status

                VStack(alignment: .leading, spacing: 0) {
                    // Status group header
                    HStack(spacing: 6) {
                        Image(systemName: status.icon)
                            .font(.caption)
                            .foregroundColor(status.color)
                        Text(status.rawValue)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(isCurrent ? .primary : .secondary)
                        if isCurrent {
                            Text("current")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(status.color.opacity(0.15))
                                .foregroundColor(status.color)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if !tasksForStatus.isEmpty {
                            let done = tasksForStatus.filter { $0.isCompleted }.count
                            Text("\(done)/\(tasksForStatus.count)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6).padding(.horizontal, 8)

                    if tasksForStatus.isEmpty {
                        Text("No tasks")
                            .font(.caption).foregroundColor(.secondary)
                            .padding(.horizontal, 8).padding(.bottom, 6)
                    } else {
                        ForEach(tasksForStatus) { task in
                            TaskRowView(
                                task: task,
                                onToggle: { store.send(.toggleTask(task.id)) },
                                onDelete: { store.send(.deleteTask(task.id)) }
                            )
                            if task.id != tasksForStatus.last?.id {
                                Divider().padding(.leading, 32)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(
                    isCurrent ? Color(NSColor.controlBackgroundColor) : Color.clear
                ))
            }
        }
    }
}

// MARK: - Notes Section

struct NotesSectionView: View {
    @Bindable var store: StoreOf<JobDetailFeature>
    let cardColors: [Color]
    @Binding var selectedNoteID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if selectedNoteID == nil {
                HStack {
                    Text("Notes")
                        .font(.headline)
                    Spacer()
                    Button { store.send(.addNote) } label: {
                        Label("New Note", systemImage: "plus").font(.footnote)
                    }
                    .buttonStyle(.bordered).controlSize(.mini)
                }
            }

            if let noteID = selectedNoteID,
               store.noteCards.contains(where: { $0.id == noteID }) {
                NoteEditorView(
                    note: Binding(
                        get: { store.noteCards.first(where: { $0.id == noteID }) ?? Note() },
                        set: { new in
                            var updated = new
                            updated.updatedAt = Date()
                            var copy = store.noteCards
                            if let idx = copy.firstIndex(where: { $0.id == updated.id }) {
                                copy[idx] = updated
                                store.send(.binding(.set(\.noteCards, copy)))
                            }
                        }
                    ),
                    onBack: { selectedNoteID = nil },
                    onDelete: {
                        store.send(.deleteNote(noteID))
                        selectedNoteID = nil
                    }
                )
            } else if store.noteCards.isEmpty {
                Text("No notes yet — add one to capture research, salary info, or anything relevant.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                    ForEach(store.noteCards) { note in
                        NoteCard(
                            note: note,
                            accentColor: cardColors[abs(note.id.hashValue) % cardColors.count],
                            onTap: { selectedNoteID = note.id }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Note Card

struct NoteCard: View {
    let note: Note
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Accent bar
                Rectangle()
                    .fill(accentColor)
                    .frame(height: 6)

                VStack(alignment: .leading, spacing: 6) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .lineLimit(1)

                    if !note.subtitle.isEmpty {
                        Text(note.subtitle)
                            .font(.footnote).foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if !note.body.isEmpty {
                        Text(note.body)
                            .font(.footnote).foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    if !note.tags.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(note.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(accentColor.opacity(0.5))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Note Editor

struct NoteEditorView: View {
    @Binding var note: Note
    let onBack: () -> Void
    let onDelete: () -> Void

    @State private var tagInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Notes")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain).foregroundColor(.accentColor)

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash").font(.footnote)
                }
                .buttonStyle(.bordered).controlSize(.mini)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    TextField("Title", text: $note.title)
                        .font(.title3).fontWeight(.semibold)
                        .textFieldStyle(.plain)

                    // Subtitle
                    TextField("Subtitle", text: $note.subtitle)
                        .font(.subheadline).foregroundColor(.secondary)
                        .textFieldStyle(.plain)

                    Divider()

                    // Tags
                    VStack(alignment: .leading, spacing: 6) {
                        if !note.tags.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(note.tags, id: \.self) { tag in
                                    HStack(spacing: 3) {
                                        Text(tag).font(.footnote)
                                        Button {
                                            note.tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark").font(.system(size: 8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .clipShape(Capsule())
                                }
                            }
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "tag").font(.footnote).foregroundColor(.secondary)
                            TextField("Add tag…", text: $tagInput)
                                .font(.footnote).textFieldStyle(.plain)
                                .onSubmit { addTag() }
                            Button("Add") { addTag() }
                                .buttonStyle(.bordered).controlSize(.mini)
                                .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    Divider()

                    // Body
                    TextEditor(text: $note.body)
                        .font(.body)
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                }
                .padding(16)
            }
        }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !note.tags.contains(trimmed) else { return }
        note.tags.append(trimmed)
        tagInput = ""
    }
}

// MARK: - Contacts Tab

struct ContactsTab: View {
    @Bindable var store: StoreOf<JobDetailFeature>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recruiters, hiring managers, connections")
                    .font(.footnote).foregroundColor(.secondary)
                Spacer()
                Button { store.send(.addContact) } label: {
                    Label("Add Contact", systemImage: "person.badge.plus").font(.footnote)
                }
                .buttonStyle(.bordered).controlSize(.mini)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if store.contacts.isEmpty {
                ContentUnavailableView("No Contacts", systemImage: "person.crop.circle.badge.xmark",
                    description: Text("Add recruiters, hiring managers, or referrals")).padding()
                Spacer()
            } else {
                List {
                    ForEach(store.contacts, id: \.id) { contact in
                        ContactRow(contact: Binding(
                            get: {
                                store.contacts.first(where: { $0.id == contact.id }) ?? contact
                            },
                            set: { new in
                                var copy = store.contacts
                                if let idx = copy.firstIndex(where: { $0.id == new.id }) {
                                    copy[idx] = new
                                    store.send(.binding(.set(\.contacts, copy)))
                                }
                            }
                        ))
                    }
                    .onDelete { indices in
                        var copy = store.contacts
                        copy.remove(atOffsets: indices)
                        store.send(.binding(.set(\.contacts, copy)))
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct ContactRow: View {
    @Binding var contact: Contact
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: contact.connected ? "person.fill.checkmark" : "person.circle")
                    .foregroundColor(contact.connected ? .green : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    TextField("Name", text: $contact.name)
                        .font(.subheadline).fontWeight(.medium).textFieldStyle(.plain)
                    TextField("Title / Role", text: $contact.title)
                        .font(.footnote).foregroundColor(.secondary).textFieldStyle(.plain)
                }
                Spacer()
                Toggle("Connected", isOn: $contact.connected)
                    .toggleStyle(.checkbox).labelsHidden().help("LinkedIn connected")
                Button { isExpanded.toggle() } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.footnote).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "envelope").frame(width: 16)
                        TextField("email@company.com", text: $contact.email)
                    }
                    HStack {
                        Image(systemName: "link").frame(width: 16)
                        TextField("linkedin.com/in/...", text: $contact.linkedin)
                    }
                    TextEditor(text: $contact.notes)
                        .frame(height: 60)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2)))
                }
                .font(.footnote).padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Interviews Tab

struct InterviewsTab: View {
    @Bindable var store: StoreOf<JobDetailFeature>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Track each interview round").font(.footnote).foregroundColor(.secondary)
                Spacer()
                Button { store.send(.addInterview) } label: {
                    Label("Add Round", systemImage: "plus").font(.footnote)
                }
                .buttonStyle(.bordered).controlSize(.mini)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))


            Divider()

            if store.interviews.isEmpty {
                ContentUnavailableView("No Interviews Yet",
                    systemImage: "calendar.badge.clock",
                    description: Text("Add interview rounds as you progress")).padding()
                Spacer()
            } else {
                List {
                    ForEach(store.interviews, id: \.id) { round in
                        InterviewRoundRow(round: Binding(
                            get: {
                                store.interviews.first(where: { $0.id == round.id }) ?? round
                            },
                            set: { new in
                                var copy = store.interviews
                                if let idx = copy.firstIndex(where: { $0.id == new.id }) {
                                    copy[idx] = new
                                    store.send(.binding(.set(\.interviews, copy)))
                                }
                            }
                        ), store: store)
                        .contextMenu {
                            Button(role: .destructive) {
                                if let idx = store.interviews.firstIndex(where: { $0.id == round.id }) {
                                    store.send(.deleteInterview(IndexSet(integer: idx)))
                                }
                            } label: {
                                Label("Delete Round", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indices in
                        store.send(.deleteInterview(indices))
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct InterviewRoundRow: View {
    @Binding var round: InterviewRound
    let store: StoreOf<JobDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Round \(round.round)",
                      systemImage: round.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(round.completed ? .green : .primary)
                    .fontWeight(.semibold).font(.subheadline)
                Spacer()
                Toggle("Done", isOn: $round.completed).toggleStyle(.checkbox).labelsHidden()
            }
            HStack(spacing: 8) {
                TextField("Type (Technical, Behavioral...)", text: $round.type)
                    .textFieldStyle(.roundedBorder).font(.footnote)
                DatePicker("", selection: Binding(
                    get: { round.date ?? Date() },
                    set: { round.date = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden().font(.footnote).frame(width: 160)
            }
            TextField("Interviewers", text: $round.interviewers).textFieldStyle(.roundedBorder).font(.footnote)
            TextEditor(text: $round.notes)
                .font(.footnote)
                .scrollContentBackground(.hidden)
                .padding(4)
                .frame(minHeight: 36, maxHeight: 120)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if round.notes.isEmpty {
                        Text("Notes / Feedback")
                            .font(.footnote).foregroundColor(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
            if round.calendarEventIdentifier != nil {
                VStack(alignment: .leading, spacing: 2) {
                    Label(round.calendarEventTitle ?? "Linked event", systemImage: "calendar")
                        .font(.footnote)
                    if let date = round.date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    Button("Unlink") {
                        store.send(.unlinkCalendarEvent(interviewId: round.id))
                    }
                    .font(.footnote)
                }
            } else if store.calendarAccessGranted == false {
                Text("Calendar access required in System Settings to link events.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            } else {
                Button {
                    store.send(.linkCalendarEvent(interviewId: round.id))
                } label: {
                    Label("Link Calendar Event", systemImage: "link")
                }
                .font(.footnote)
            }
            if let warning = store.calendarSyncWarnings[round.id], warning == .eventMissing {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Event deleted from Calendar")
                        .font(.footnote)
                    Spacer()
                    Button("Unlink") {
                        store.send(.unlinkCalendarEvent(interviewId: round.id))
                        store.send(.dismissCalendarSyncWarning(interviewId: round.id))
                    }
                    .font(.footnote)
                }
            }
        }
        .padding(.vertical, 4)
        .popover(isPresented: Binding(
            get: { store.showCalendarPicker && store.calendarPickerInterviewId == round.id },
            set: { if !$0 { store.send(.dismissCalendarPicker) } }
        )) {
            CalendarEventPickerView(
                events: store.calendarEvents,
                searchQuery: Binding(
                    get: { store.calendarSearchQuery },
                    set: { store.send(.calendarSearchQueryChanged($0)) }
                ),
                onSelect: { event in store.send(.calendarEventSelected(interviewId: round.id, event: event)) },
                onCancel: { store.send(.dismissCalendarPicker) }
            )
        }
    }
}

// MARK: - Documents Tab

struct DocumentsTab: View {
    let store: StoreOf<JobDetailFeature>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Attached documents (drag files onto job cards to add)")
                    .font(.footnote).foregroundColor(.secondary)
                Spacer()
                Text("\(store.job.documents.count) document\(store.job.documents.count == 1 ? "" : "s")")
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if store.job.documents.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Documents",
                    systemImage: "paperclip",
                    description: Text("Drag PDF, DOCX, RTF, or TXT files onto a job card to attach them")
                )
                Spacer()
            } else {
                List {
                    ForEach(store.job.documents) { doc in
                        DocumentRow(
                            document: doc,
                            onDelete: { store.send(.deleteDocument(doc.id)) },
                            onProcess: { store.send(.processDocumentWithAI(doc.id)) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct DocumentRow: View {
    let document: JobDocument
    let onDelete: () -> Void
    let onProcess: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: document.documentType.icon)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(document.filename)
                        .font(.subheadline).fontWeight(.medium)
                    HStack(spacing: 8) {
                        Text(document.documentType.rawValue.uppercased())
                            .font(.caption2).foregroundColor(.secondary)
                        if let size = document.fileSize {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Text(document.addedAt.relativeString)
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Process with AI") { onProcess() }
                    .buttonStyle(.bordered).controlSize(.mini)
                Button { isExpanded.toggle() } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.footnote).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                ScrollView {
                    Text(document.rawText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 200)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
            }
        }
        .padding(.vertical, 4)
        .onTapGesture(count: 2) {
            if let path = document.sourcePath {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }
        }
        .contextMenu {
            if document.sourcePath != nil {
                Button {
                    if let path = document.sourcePath {
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }
                } label: {
                    Label("Open in Default App", systemImage: "arrow.up.forward.app")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete Document", systemImage: "trash")
            }
        }
    }
}

