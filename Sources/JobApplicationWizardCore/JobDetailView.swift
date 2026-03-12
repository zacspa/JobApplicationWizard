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
            TabView(selection: Binding(
                get: { store.selectedTab },
                set: { store.send(.selectTab($0)) }
            )) {
                OverviewTab(store: store)
                    .tabItem { Label("Overview", systemImage: "info.circle") }
                    .tag(JobDetailFeature.State.Tab.overview)

                DescriptionTab(store: store)
                    .tabItem { Label("Description", systemImage: "doc.text") }
                    .tag(JobDetailFeature.State.Tab.description)

                NotesTab(store: store)
                    .tabItem { Label("Notes", systemImage: "note.text") }
                    .tag(JobDetailFeature.State.Tab.notes)

                ContactsTab(store: store)
                    .tabItem { Label("Contacts", systemImage: "person.2") }
                    .tag(JobDetailFeature.State.Tab.contacts)

                InterviewsTab(store: store)
                    .tabItem { Label("Interviews", systemImage: "calendar.badge.clock") }
                    .tag(JobDetailFeature.State.Tab.interviews)

                AIAssistantTab(store: store)
                    .tabItem { Label("AI", systemImage: "sparkles") }
                    .tag(JobDetailFeature.State.Tab.ai)
            }
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
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.job.displayCompany)
                        .font(.title3).fontWeight(.bold)
                    Text(store.job.displayTitle)
                        .font(.subheadline).foregroundColor(.secondary)
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
                            Button { store.send(.moveJob(s)) } label: {
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

                Spacer()

                HStack(spacing: 4) {
                    Text("Excitement:").font(.footnote).foregroundColor(.secondary)
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
                    VStack(spacing: 0) {
                        HStack {
                            Label("Added", systemImage: "plus.circle")
                                .font(.subheadline).foregroundColor(.secondary).frame(width: 120, alignment: .leading)
                            Text(store.job.dateAdded.formatted(date: .abbreviated, time: .omitted)).font(.subheadline)
                        }
                        .padding(.vertical, 7).padding(.horizontal, 8)
                        Divider()
                        HStack {
                            Label("Applied", systemImage: "paperplane")
                                .font(.subheadline).foregroundColor(.secondary).frame(width: 120, alignment: .leading)
                            if let applied = store.job.dateApplied {
                                Text(applied.formatted(date: .abbreviated, time: .omitted)).font(.subheadline)
                            } else {
                                Text("Not yet applied").font(.subheadline).foregroundColor(.secondary)
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
                            HStack {
                                Label {
                                    Text(interview.type.isEmpty ? "Round \(interview.round)" : "Round \(interview.round) · \(interview.type)")
                                } icon: {
                                    Image(systemName: interview.completed ? "checkmark.circle.fill" : "person.line.dotted.person")
                                        .foregroundColor(interview.completed ? .green : .secondary)
                                }
                                .font(.subheadline).foregroundColor(.secondary).frame(width: 120, alignment: .leading)
                                if let date = interview.date {
                                    Text(date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 7).padding(.horizontal, 8)
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
                .frame(width: 110, alignment: .leading)
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
        } else {
            NoteCardGridView(
                store: store,
                cardColors: NotesTab.cardColors,
                onSelectNote: { selectedNoteID = $0 }
            )
        }
    }
}

// MARK: - Note Card Grid

struct NoteCardGridView: View {
    @Bindable var store: StoreOf<JobDetailFeature>
    let cardColors: [Color]
    let onSelectNote: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notes about this application")
                    .font(.footnote).foregroundColor(.secondary)
                Spacer()
                Button { store.send(.addNote) } label: {
                    Label("New Note", systemImage: "plus").font(.footnote)
                }
                .buttonStyle(.bordered).controlSize(.mini)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if store.noteCards.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Notes Yet",
                    systemImage: "note.text",
                    description: Text("Add your first note to capture research, salary info, or anything relevant")
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                        ForEach(store.noteCards) { note in
                            NoteCard(
                                note: note,
                                accentColor: cardColors[abs(note.id.hashValue) % cardColors.count],
                                onTap: { onSelectNote(note.id) }
                            )
                        }
                    }
                    .padding(16)
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
                        ))
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
            TextField("Notes / Feedback", text: $round.notes).textFieldStyle(.roundedBorder).font(.footnote)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AI Assistant Tab (Chat UI)

struct AIAssistantTab: View {
    @Bindable var store: StoreOf<JobDetailFeature>
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Mode picker + token usage
            HStack(spacing: 12) {
                Picker("", selection: $store.aiSelectedAction) {
                    ForEach(AIAction.allCases, id: \.self) { a in
                        Text(a.rawValue).tag(a)
                    }
                }
                .pickerStyle(.segmented)

                if store.aiTokenUsage.totalTokens > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(store.aiTokenUsage.totalTokens.formatted()) tok")
                            .font(.footnote).fontWeight(.medium).foregroundColor(.secondary)
                        Text(String(format: "~$%.4f", store.aiTokenUsage.estimatedCost))
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if store.apiKey.isEmpty {
                HStack {
                    Image(systemName: "key.fill").foregroundColor(.orange)
                    Text("Add your Claude API key in Settings to use AI features.").font(.subheadline)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                Spacer()
            }

            // Message history
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if store.chatMessages.isEmpty {
                            VStack(spacing: 8) {
                                Text("✦").font(.system(size: 28))
                                Text("Ask Claude anything about this application,\nor choose a quick action above.")
                                    .font(.subheadline).foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            ForEach(store.chatMessages) { msg in
                                ChatBubble(message: msg)
                                    .id(msg.id)
                            }
                            if store.aiIsLoading {
                                ThinkingBubble()
                                    .id("thinking")
                            }
                        }
                    }
                    .padding(16)
                }
                .onChange(of: store.chatMessages.count) { _, _ in
                    if let last = store.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: store.aiIsLoading) { _, loading in
                    if loading {
                        withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Input bar
            VStack(spacing: 6) {
                if let error = store.aiError {
                    Text(error).font(.footnote).foregroundColor(.red)
                        .padding(8).background(Color.red.opacity(0.1)).cornerRadius(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        if store.aiInput.isEmpty {
                            Text(inputPlaceholder)
                                .foregroundColor(.secondary)
                                .font(.body)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $store.aiInput)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .font(.body)
                            .frame(minHeight: 34, maxHeight: 100)
                            .focused($inputFocused)
                            .disabled(store.apiKey.isEmpty || store.aiIsLoading)
                            .onKeyPress(keys: [.return]) { press in
                                if press.modifiers.contains(.shift) {
                                    return .ignored  // insert newline
                                }
                                if canSend {
                                    store.send(.sendMessage)
                                    Task { @MainActor in inputFocused = true }
                                }
                                return .handled
                            }
                    }
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    Button {
                        store.send(.sendMessage)
                        Task { @MainActor in inputFocused = true }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(canSend ? .accentColor : .secondary)
                    .disabled(!canSend)
                }
                .onAppear { inputFocused = true }
                HStack {
                    Button("Clear conversation") { store.send(.clearChat) }
                        .buttonStyle(.plain).font(.footnote).foregroundColor(.secondary)
                        .disabled(store.chatMessages.isEmpty)
                    Spacer()
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    var canSend: Bool {
        !store.aiIsLoading && !store.apiKey.isEmpty
            && !store.aiInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var inputPlaceholder: String {
        switch store.aiSelectedAction {
        case .chat: return "Ask a follow-up..."
        case .tailorResume: return "Paste your resume / experience summary..."
        case .coverLetter: return "Brief background / key achievements..."
        case .interviewPrep: return "Your background (optional)..."
        case .analyzeFit: return "Your background / experience summary..."
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .assistant {
                bubbleContent
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 60)
                bubbleContent
            }
        }
    }

    var bubbleContent: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .font(.body)
                .textSelection(.enabled)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    message.role == .user
                        ? Color.accentColor.opacity(0.15)
                        : Color(NSColor.controlBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if message.role == .assistant && isHovered {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.content, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc").font(.footnote)
                }
                .buttonStyle(.plain).foregroundColor(.secondary)
            }
        }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Thinking Bubble

struct ThinkingBubble: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(alignment: .top) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary.opacity(phase == i ? 1.0 : 0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            Spacer()
        }
        .onAppear {
            withAnimation(.linear(duration: 0.4).repeatForever(autoreverses: false)) {
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { y += rowHeight + spacing; x = 0; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { y += rowHeight + spacing; x = bounds.minX; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
