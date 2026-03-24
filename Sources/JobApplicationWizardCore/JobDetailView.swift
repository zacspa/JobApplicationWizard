import SwiftUI
import ComposableArchitecture

// MARK: - Job Detail Panel

public struct JobDetailView: View {
    @Bindable var store: StoreOf<JobDetailFeature>
    let calendarStore: StoreOf<CalendarFeature>

    public init(store: StoreOf<JobDetailFeature>, calendarStore: StoreOf<CalendarFeature>) {
        self.store = store
        self.calendarStore = calendarStore
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
        .environment(\.dsLaneAccent, store.job.status.color)
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
                            .font(DS.Typography.subheadline)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(store.selectedTab == tab ? Color.accentColor.opacity(DS.Color.Opacity.wash) : Color.clear)
                            .foregroundColor(store.selectedTab == tab ? .accentColor : .secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
        }
        .background(DS.Color.controlBackground)
    }

    @ViewBuilder
    var tabContent: some View {
        switch store.selectedTab {
        case .overview: OverviewTab(store: store)
        case .description: DescriptionTab(store: store)
        case .notes: NotesTab(store: store)
        case .contacts: ContactsTab(store: store)
        case .interviews: InterviewsTab(store: store, calendarStore: calendarStore)
        case .documents: DocumentsTab(store: store)
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(store.job.displayCompany)
                        .font(DS.Typography.heading2).fontWeight(.bold)
                        .lineLimit(2)
                    Text(store.job.displayTitle)
                        .font(DS.Typography.subheadline).foregroundColor(DS.Color.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                HStack(spacing: DS.Spacing.sm) {
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
                        Image(systemName: "ellipsis.circle").foregroundColor(DS.Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Label(store.job.status.rawValue, systemImage: store.job.status.icon)
                    .font(DS.Typography.footnote).fontWeight(.semibold)
                    .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.xxs)
                    .background(store.job.status.color.opacity(DS.Color.Opacity.tint))
                    .foregroundColor(store.job.status.color)
                    .clipShape(Capsule())

                Spacer(minLength: 8)

                HStack(spacing: DS.Spacing.xxs) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= store.job.excitement ? "star.fill" : "star")
                            .font(DS.Typography.footnote).foregroundColor(.orange)
                            .onTapGesture { store.send(.setExcitement(i)) }
                    }
                }
            }

            if !store.job.labels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(store.job.labels) { label in
                            HStack(spacing: 3) {
                                Circle().fill(label.color).frame(width: 6, height: 6)
                                Text(label.name).font(DS.Typography.footnote)
                            }
                            .padding(.horizontal, DS.Spacing.sm).padding(.vertical, DS.Spacing.xxxs)
                            .background(label.color.opacity(DS.Color.Opacity.wash)).clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Color.controlBackground)
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    @Bindable var store: StoreOf<JobDetailFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                GroupBox("Application Details") {
                    VStack(spacing: 0) {
                        DetailRow(icon: "building.2", label: "Company") {
                            DSTextField("Company name", text: $store.company)
                                .outlinedField("Company", isEmpty: store.company.isEmpty)
                        }
                        Divider()
                        DetailRow(icon: "briefcase", label: "Title") {
                            DSTextField("Job title", text: $store.title)
                                .outlinedField("Title", isEmpty: store.title.isEmpty)
                        }
                        Divider()
                        DetailRow(icon: "mappin.circle", label: "Location") {
                            DSTextField("City, State / Remote", text: $store.location)
                                .outlinedField("Location", isEmpty: store.location.isEmpty)
                        }
                        Divider()
                        DetailRow(icon: "dollarsign.circle", label: "Salary") {
                            DSTextField("e.g. $120k-150k", text: $store.salary)
                                .outlinedField("Salary", isEmpty: store.salary.isEmpty)
                        }
                        Divider()
                        DetailRow(icon: "link", label: "URL") {
                            DSTextField("https://...", text: $store.url)
                                .outlinedField("URL", isEmpty: store.url.isEmpty)
                        }
                    }
                }

                GroupBox("Timeline") {
                    VStack(spacing: 0) {
                        timelineRow(
                            icon: "plus.circle",
                            iconColor: .secondary,
                            label: "Added",
                            date: store.job.dateAdded.formatted(date: .abbreviated, time: .omitted)
                        )
                        Divider()
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "paperplane")
                                .foregroundColor(DS.Color.textSecondary)
                                .frame(width: 20)
                            Text("Applied")
                                .font(DS.Typography.subheadline)
                                .lineLimit(1)
                            Spacer()
                            if let applied = store.job.dateApplied {
                                Text(applied.formatted(date: .abbreviated, time: .omitted))
                                    .font(DS.Typography.subheadline)
                                    .foregroundColor(DS.Color.textSecondary)
                            } else {
                                Button("Mark Applied") { store.send(.markApplied) }
                                    .font(DS.Typography.subheadline).buttonStyle(DSActionButtonStyle())
                            }
                        }
                        .detailRow()

                        let sorted = store.job.interviews.sorted { a, b in
                            // Interviews with dates first (sorted by date), then no-date sorted by round
                            switch (a.date, b.date) {
                            case let (ad?, bd?): return ad < bd
                            case (_?, nil): return true
                            case (nil, _?): return false
                            case (nil, nil): return a.round < b.round
                            }
                        }
                        ForEach(sorted) { interview in
                            Divider()
                            timelineRow(
                                icon: interview.completed ? "checkmark.circle.fill" : "person.line.dotted.person",
                                iconColor: interview.completed ? .green : .secondary,
                                label: interview.type.isEmpty
                                    ? "Round \(interview.round)"
                                    : "Round \(interview.round) · \(interview.type)",
                                date: interview.date?.formatted(date: .abbreviated, time: .omitted)
                            )
                        }
                    }
                }

                GroupBox("Resume & Documents") {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Label("Resume Version", systemImage: "doc.fill")
                                .font(DS.Typography.subheadline).foregroundColor(DS.Color.textSecondary)
                            Spacer()
                        }
                        DSTextField("e.g. resume_v3_tailored.pdf", text: $store.resumeUsed)
                            .outlinedField("Resume Used", isEmpty: store.resumeUsed.isEmpty)
                    }
                    .padding(DS.Spacing.xxs)
                }

                GroupBox("Labels") {
                    LabelsEditor(labels: $store.labels).padding(4)
                }
            }
            .padding(DS.Spacing.lg)
        }
    }

    private func timelineRow(icon: String, iconColor: Color, label: String, date: String?) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            Text(label)
                .font(DS.Typography.subheadline)
                .lineLimit(1)
            Spacer()
            if let date {
                Text(date)
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Color.textSecondary)
            }
        }
        .detailRow()
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
                .font(DS.Typography.subheadline)
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
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.sm)
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
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Color.textSecondary)
                .frame(width: 20)
            content()
        }
        .detailRow()
    }
}

// MARK: - Labels Editor

struct LabelsEditor: View {
    @Binding var labels: [JobLabel]
    @State private var customName = ""
    @State private var customColor = Color.blue

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            FlowLayout(spacing: DS.Spacing.xs) {
                ForEach(labels) { label in
                    HStack(spacing: 3) {
                        Text(label.name).font(DS.Typography.footnote)
                        Button {
                            labels.removeAll { $0.id == label.id }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DS.Spacing.sm).padding(.vertical, DS.Spacing.xxxs)
                    .background(label.color.opacity(DS.Color.Opacity.tint)).foregroundColor(label.color)
                    .clipShape(Capsule())
                }
            }

            Text("Quick add:").font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
            FlowLayout(spacing: DS.Spacing.xxs) {
                ForEach(JobLabel.presets.filter { p in !labels.contains { $0.name == p.name } }) { preset in
                    Button { labels.append(preset) } label: {
                        Text("+ \(preset.name)")
                            .font(DS.Typography.footnote).padding(.horizontal, DS.Spacing.xs).padding(.vertical, DS.Spacing.xxxs)
                            .background(Color.secondary.opacity(DS.Color.Opacity.subtle)).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: DS.Spacing.sm) {
                ColorPicker("Color", selection: $customColor)
                    .labelsHidden()
                    .frame(width: 32, height: 32)
                    .fixedSize()
                DSTextField("Custom label...", text: $customName)
                    .outlinedField("Label", isEmpty: customName.isEmpty)
                Button("Add") {
                    guard !customName.isEmpty else { return }
                    labels.append(JobLabel(name: customName, colorHex: customColor.hexString))
                    customName = ""
                }
                .buttonStyle(DSActionButtonStyle())
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
                    .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                Spacer()

                if store.job.hasPDF {
                    Button { store.send(.viewPDFTapped) } label: {
                        Label("View PDF", systemImage: "doc.fill").font(DS.Typography.footnote)
                    }
                    .buttonStyle(DSActionButtonStyle())
                }

                if !store.jobDescription.isEmpty {
                    Button { store.send(.savePDFTapped) } label: {
                        if store.isGeneratingPDF {
                            HStack(spacing: DS.Spacing.xxs) {
                                ProgressView().controlSize(.mini)
                                Text("Saving…").font(DS.Typography.footnote)
                            }
                        } else {
                            Label("Save PDF", systemImage: "square.and.arrow.down").font(DS.Typography.footnote)
                        }
                    }
                    .buttonStyle(DSActionButtonStyle()).disabled(store.isGeneratingPDF)

                    Button { store.send(.printTapped) } label: {
                        Label("Print", systemImage: "printer").font(DS.Typography.footnote)
                    }
                    .buttonStyle(DSActionButtonStyle())

                    Button { store.send(.copyDescriptionTapped) } label: {
                        Label(store.showCopied ? "Copied!" : "Copy",
                              systemImage: store.showCopied ? "checkmark" : "doc.on.doc")
                            .font(DS.Typography.footnote)
                    }
                    .buttonStyle(DSActionButtonStyle())

                    Text("\(store.jobDescription.wordCount) words")
                        .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                }
            }
            .actionBar()

            if let err = store.pdfError {
                Text(err).font(DS.Typography.footnote).foregroundColor(.red)
                    .padding(.horizontal, DS.Spacing.lg).padding(.vertical, DS.Spacing.xxs)
                    .background(Color.red.opacity(DS.Color.Opacity.subtle))
            }

            Divider()

            TextEditor(text: $store.jobDescription)
                .font(DS.Typography.body)
                .scrollContentBackground(.hidden)
                .outlinedField("Job Description", isEmpty: store.jobDescription.isEmpty)
                .padding(DS.Spacing.md)
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
                accentColor: NotesTab.cardColors[abs(noteID.hashValue) % NotesTab.cardColors.count],
                onBack: { selectedNoteID = nil },
                onDelete: {
                    store.send(.deleteNote(noteID))
                    selectedNoteID = nil
                }
            )
            .padding(DS.Spacing.lg)
        } else {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    TasksSectionView(store: store)
                    NotesSectionView(
                        store: store,
                        cardColors: NotesTab.cardColors,
                        selectedNoteID: $selectedNoteID
                    )
                }
                .padding(DS.Spacing.lg)
            }
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
                    .sectionHeaderStyle()
                Spacer()
                if !store.isAddingTask {
                    Button { store.send(.addTaskTapped) } label: {
                        Label("Add Task", systemImage: "plus").font(DS.Typography.footnote)
                    }
                    .buttonStyle(DSActionButtonStyle())
                }
            }
            .padding(.bottom, DS.Spacing.md)

            // Add task UI (adds to current status)
            if store.isAddingTask {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    let suggestions = store.job.status.suggestedTaskTitles.filter { s in
                        !store.job.tasks.contains { $0.title == s && $0.forStatus == store.job.status }
                    }
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Spacing.xs) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button { store.send(.addSuggestedTask(suggestion)) } label: {
                                        Text("+ \(suggestion)")
                                            .font(DS.Typography.footnote)
                                            .padding(.horizontal, DS.Spacing.sm)
                                            .padding(.vertical, DS.Spacing.xxs)
                                            .background(Color.accentColor.opacity(DS.Color.Opacity.subtle))
                                            .foregroundColor(.accentColor)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    HStack {
                        DSTextField("Task title...", text: Binding(
                            get: { store.newTaskText },
                            set: { store.send(.newTaskTextChanged($0)) }
                        ), onSubmit: { store.send(.saveNewTask) })
                        .outlinedField("Task", isEmpty: store.newTaskText.isEmpty)
                        Button("Save") { store.send(.saveNewTask) }
                            .buttonStyle(DSActionButtonStyle())
                            .disabled(store.newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Cancel") { store.send(.cancelNewTask) }
                            .buttonStyle(GhostButtonStyle())
                    }
                }
                .padding(DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.medium).fill(DS.Color.controlBackground))
                .padding(.bottom, DS.Spacing.sm)
            }

            // Grouped by status
            ForEach(statusesWithTasks) { status in
                let tasksForStatus = store.job.tasks.filter { $0.forStatus == status }
                let isCurrent = status == store.job.status

                VStack(alignment: .leading, spacing: 0) {
                    // Status group header
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: status.icon)
                            .font(DS.Typography.caption)
                            .foregroundColor(status.color)
                        Text(status.rawValue)
                            .font(DS.Typography.subheadline).fontWeight(.medium)
                            .foregroundColor(isCurrent ? .primary : .secondary)
                        if isCurrent {
                            Text("current")
                                .font(DS.Typography.micro)
                                .padding(.horizontal, DS.Spacing.xs).padding(.vertical, 1)
                                .background(status.color.opacity(DS.Color.Opacity.tint))
                                .foregroundColor(status.color)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if !tasksForStatus.isEmpty {
                            let done = tasksForStatus.filter { $0.isCompleted }.count
                            Text("\(done)/\(tasksForStatus.count)")
                                .font(DS.Typography.caption).foregroundColor(DS.Color.textSecondary)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs).padding(.horizontal, DS.Spacing.sm)

                    if tasksForStatus.isEmpty {
                        Text("No tasks")
                            .font(DS.Typography.caption).foregroundColor(DS.Color.textSecondary)
                            .padding(.horizontal, DS.Spacing.sm).padding(.bottom, DS.Spacing.xs)
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
                .padding(.vertical, DS.Spacing.xxs)
                .background(RoundedRectangle(cornerRadius: DS.Radius.medium).fill(
                    isCurrent ? DS.Color.controlBackground : Color.clear
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Notes")
                    .sectionHeaderStyle()
                Spacer()
                Button { store.send(.addNote) } label: {
                    Label("New Note", systemImage: "plus").font(DS.Typography.footnote)
                }
                .buttonStyle(DSActionButtonStyle())
            }

            if store.noteCards.isEmpty {
                Text("No notes yet; add one to capture research, salary info, or anything relevant.")
                    .font(DS.Typography.subheadline).foregroundColor(DS.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.Spacing.xl)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: DS.Spacing.md) {
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

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(DS.Typography.subheadline).fontWeight(.semibold)
                        .lineLimit(1)

                    if !note.subtitle.isEmpty {
                        Text(note.subtitle)
                            .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                            .lineLimit(1)
                    }

                    if !note.body.isEmpty {
                        Text(note.body)
                            .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                            .lineLimit(2)
                    }

                    if !note.tags.isEmpty {
                        FlowLayout(spacing: DS.Spacing.xxs) {
                            ForEach(note.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(DS.Typography.caption)
                                    .padding(.horizontal, DS.Spacing.xs).padding(.vertical, DS.Spacing.xxxs)
                                    .background(accentColor.opacity(0.5))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DS.Color.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.large))
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.large)
                .stroke(Color.secondary.opacity(DS.Color.Opacity.tint), lineWidth: 1)
        )
        .dsShadow(DS.Shadow.card)
    }
}

// MARK: - Note Editor

struct NoteEditorView: View {
    @Binding var note: Note
    var accentColor: Color = .accentColor
    let onBack: () -> Void
    let onDelete: () -> Void

    @State private var tagInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent bar matching the note card
            Rectangle()
                .fill(accentColor)
                .frame(height: 6)

            // Nav bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "chevron.left")
                        Text("Notes")
                    }
                    .font(DS.Typography.subheadline)
                }
                .buttonStyle(.plain).foregroundColor(.accentColor)

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash").font(DS.Typography.footnote)
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    // Title as inline heading
                    DSTextField("Untitled", text: $note.title, font: .systemFont(ofSize: 20, weight: .bold))
                        .frame(minHeight: 28)

                    // Subtitle as secondary text
                    DSTextField("Add a subtitle...", text: $note.subtitle, font: .systemFont(ofSize: 13))
                        .opacity(note.subtitle.isEmpty ? 0.5 : 1.0)

                    // Tags
                    HStack(spacing: DS.Spacing.xs) {
                        if !note.tags.isEmpty {
                            FlowLayout(spacing: DS.Spacing.xs) {
                                ForEach(note.tags, id: \.self) { tag in
                                    HStack(spacing: 3) {
                                        Text(tag).font(DS.Typography.caption)
                                        Button {
                                            note.tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark").font(.system(size: 8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, DS.Spacing.xxs)
                                    .background(accentColor.opacity(0.5))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        DSTextField("Add tag...", text: $tagInput, font: .systemFont(ofSize: 10), onSubmit: addTag)
                            .frame(maxWidth: 120)
                    }

                    Divider().padding(.vertical, DS.Spacing.xs)

                    // Body
                    TextEditor(text: $note.body)
                        .font(DS.Typography.body)
                        .focusEffectDisabled()
                        .scrollDisabled(true)
                        .scrollContentBackground(.hidden)
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(DS.Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.large)
                .stroke(Color.secondary.opacity(DS.Color.Opacity.tint), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
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
                    .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                Spacer()
                Button { store.send(.addContact) } label: {
                    Label("Add Contact", systemImage: "person.badge.plus").font(DS.Typography.footnote)
                }
                .buttonStyle(DSActionButtonStyle())
            }
            .actionBar()

            if store.contacts.isEmpty {
                ContentUnavailableView("No Contacts", systemImage: "person.crop.circle.badge.xmark",
                    description: Text("Add recruiters, hiring managers, or referrals")).padding()
                Spacer()
            } else {
                List {
                    ForEach(store.contacts, id: \.id) { contact in
                        ContactRow(
                            contact: Binding(
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
                            ),
                            onDelete: {
                                var copy = store.contacts
                                copy.removeAll { $0.id == contact.id }
                                store.send(.binding(.set(\.contacts, copy)))
                            }
                        )
                    }
                    .onDelete { indices in
                        var copy = store.contacts
                        copy.remove(atOffsets: indices)
                        store.send(.binding(.set(\.contacts, copy)))
                    }
                    .listRowSeparator(.hidden)
                }
                .listStyle(.inset)
            }
        }
    }
}

struct ContactRow: View {
    @Binding var contact: Contact
    let onDelete: (() -> Void)?
    @State private var isExpanded = false

    init(contact: Binding<Contact>, onDelete: (() -> Void)? = nil) {
        self._contact = contact
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header: icon, name summary, toggle, chevron
            HStack {
                Image(systemName: contact.connected ? "person.fill.checkmark" : "person.circle")
                    .font(DS.Typography.heading2)
                    .foregroundColor(contact.connected ? .green : DS.Color.textSecondary)
                VStack(alignment: .leading, spacing: DS.Spacing.xxxs) {
                    Text(contact.name.isEmpty ? "New Contact" : contact.name)
                        .font(DS.Typography.bodySemibold)
                    if !contact.title.isEmpty {
                        Text(contact.title)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Color.textSecondary)
                    }
                }
                Spacer()
                Toggle("Connected", isOn: $contact.connected)
                    .toggleStyle(.checkbox).labelsHidden().help("LinkedIn connected")
                Image(systemName: "chevron.right")
                    .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                let anim: Animation = isExpanded ? .easeIn(duration: 0.2) : .easeOut(duration: 0.25)
                withAnimation(anim) { isExpanded.toggle() }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSTextField("Name", text: $contact.name, font: .systemFont(ofSize: 13, weight: .medium))
                    .outlinedField("Name", isEmpty: contact.name.isEmpty)
                DSTextField("Title / Role", text: $contact.title)
                    .outlinedField("Title", isEmpty: contact.title.isEmpty)
                DSTextField("Email", text: $contact.email)
                    .outlinedField("Email", isEmpty: contact.email.isEmpty)
                DSTextField("LinkedIn", text: $contact.linkedin)
                    .outlinedField("LinkedIn", isEmpty: contact.linkedin.isEmpty)
                DSOutlinedTextEditor("Notes", text: $contact.notes, minHeight: 48)

                if let onDelete {
                    HStack {
                        Spacer()
                        Button(role: .destructive, action: onDelete) {
                            Label("Remove Contact", systemImage: "trash")
                                .font(DS.Typography.footnote)
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }
            }
            .frame(maxHeight: isExpanded ? .infinity : 0, alignment: .top)
            .opacity(isExpanded ? 1 : 0)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, isExpanded ? DS.Spacing.md : DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.medium)
                .fill(DS.Color.controlBackground)
        )
        .dsShadow(DS.Shadow.card)
    }
}

// MARK: - Interviews Tab

struct InterviewsTab: View {
    @Bindable var store: StoreOf<JobDetailFeature>
    let calendarStore: StoreOf<CalendarFeature>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Track each interview round").font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                Spacer()
                Button { store.send(.addInterview) } label: {
                    Label("Add Round", systemImage: "plus").font(DS.Typography.footnote)
                }
                .buttonStyle(DSActionButtonStyle())
            }
            .actionBar()


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
                        ), jobId: store.job.id, calendarStore: calendarStore)
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
                    .listRowSeparator(.hidden)
                }
                .listStyle(.inset)
            }
        }
    }
}

struct InterviewRoundRow: View {
    @Binding var round: InterviewRound
    let jobId: UUID
    let calendarStore: StoreOf<CalendarFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Label("Round \(round.round)",
                      systemImage: round.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(round.completed ? .green : .primary)
                    .fontWeight(.semibold).font(DS.Typography.subheadline)
                Spacer()
                Toggle("Done", isOn: $round.completed).toggleStyle(.checkbox).labelsHidden()
            }
            DSTextField("Type", text: $round.type)
                .outlinedField("Type", isEmpty: round.type.isEmpty)
            DSDateField("Date & Time", date: $round.date)
            DSTextField("Interviewers", text: $round.interviewers)
                .outlinedField("Interviewers", isEmpty: round.interviewers.isEmpty)
            DSOutlinedTextEditor("Notes", text: $round.notes, minHeight: 36)
            if round.calendarEventIdentifier != nil {
                VStack(alignment: .leading, spacing: 2) {
                    Label(round.calendarEventTitle ?? "Linked event", systemImage: "calendar")
                        .font(DS.Typography.footnote)
                    if let date = round.date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                    }
                    Button("Unlink") {
                        calendarStore.send(.unlinkEvent(jobId: jobId, interviewId: round.id))
                    }
                    .font(DS.Typography.footnote)
                }
            } else if calendarStore.accessGranted == false {
                Text("Calendar access required in System Settings to link events.")
                    .foregroundColor(DS.Color.textSecondary)
                    .font(DS.Typography.footnote)
            } else {
                Button {
                    calendarStore.send(.openPicker(jobId: jobId, interviewId: round.id))
                } label: {
                    Label("Link Calendar Event", systemImage: "link")
                }
                .font(DS.Typography.footnote)
            }
            if let warning = calendarStore.syncWarnings[InterviewKey(jobId: jobId, interviewId: round.id)], warning == .eventMissing {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Event deleted from Calendar")
                        .font(DS.Typography.footnote)
                    Spacer()
                    Button("Unlink") {
                        calendarStore.send(.unlinkEvent(jobId: jobId, interviewId: round.id))
                    }
                    .font(DS.Typography.footnote)
                }
            }
        }
        .cardStyle()
        .popover(isPresented: Binding(
            get: { calendarStore.showPicker && calendarStore.pickerInterviewId == round.id },
            set: { if !$0 { calendarStore.send(.dismissPicker) } }
        )) {
            CalendarEventPickerView(
                events: calendarStore.events,
                searchQuery: Binding(
                    get: { calendarStore.searchQuery },
                    set: { calendarStore.send(.searchQueryChanged($0)) }
                ),
                onSelect: { event in calendarStore.send(.eventSelected(event)) },
                onCancel: { calendarStore.send(.dismissPicker) }
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
                    .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                Spacer()
                Text("\(store.job.documents.count) document\(store.job.documents.count == 1 ? "" : "s")")
                    .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
            }
            .actionBar()

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
                    .listRowSeparator(.hidden)
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
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: document.documentType.icon)
                    .font(DS.Typography.heading2)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: DS.Spacing.xxxs) {
                    Text(document.filename)
                        .font(DS.Typography.subheadline).fontWeight(.medium)
                    HStack(spacing: DS.Spacing.sm) {
                        Text(document.documentType.rawValue.uppercased())
                            .font(DS.Typography.caption2)
                            .padding(.horizontal, DS.Spacing.xs).padding(.vertical, 1)
                            .background(Color.accentColor.opacity(DS.Color.Opacity.subtle))
                            .clipShape(Capsule())
                        if let size = document.fileSize {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                .font(DS.Typography.caption2).foregroundColor(DS.Color.textSecondary)
                        }
                        Text(document.addedAt.relativeString)
                            .font(DS.Typography.caption2).foregroundColor(DS.Color.textSecondary)
                    }
                }
                Spacer()
                if isHovered {
                    Button("Process with AI") { onProcess() }
                        .buttonStyle(DSActionButtonStyle())
                }
                Button { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } } label: {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Text(document.rawText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.sm)
                    .frame(maxHeight: 200)
                    .background(DS.Color.textBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.small).stroke(DS.Color.border))
            }
        }
        .cardStyle()
        .onHover { isHovered = $0 }
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

