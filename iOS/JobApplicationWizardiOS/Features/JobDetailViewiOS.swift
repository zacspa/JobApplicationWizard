import SwiftUI
import ComposableArchitecture
import JobApplicationShared

struct JobDetailViewiOS: View {
    let store: StoreOf<iOSAppFeature>
    let jobId: UUID

    @State private var showStatusPicker = false
    @State private var showAddNote = false
    @State private var newNoteTitle = ""
    @State private var newNoteBody = ""

    private var job: JobApplication {
        store.jobs[id: jobId] ?? JobApplication()
    }

    var body: some View {
        if store.jobs[id: jobId] != nil {
            List {
                headerSection
                infoSection
                labelsSection
                notesSection
                contactsSection
                interviewsSection
                tasksSection
            }
            .navigationTitle(job.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            store.send(.toggleFavorite(job.id))
                        } label: {
                            Label(
                                job.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: job.isFavorite ? "star.slash" : "star.fill"
                            )
                        }
                        Button {
                            showStatusPicker = true
                        } label: {
                            Label("Change Status", systemImage: "arrow.triangle.swap")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Change Status", isPresented: $showStatusPicker) {
                ForEach(JobStatus.allCases) { status in
                    Button(status.rawValue) {
                        store.send(.moveJob(job.id, status))
                    }
                }
            }
            .sheet(isPresented: $showAddNote) {
                addNoteSheet
            }
        } else {
            ContentUnavailableView("Job Not Found", systemImage: "questionmark.circle")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.displayCompany)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(job.displayTitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: job.status)
                    if job.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            }

            if job.excitement > 0 {
                HStack {
                    Text("Excitement")
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= job.excitement ? "flame.fill" : "flame")
                                .foregroundStyle(i <= job.excitement ? .orange : .gray.opacity(0.3))
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private var infoSection: some View {
        Section("Details") {
            if !job.location.isEmpty {
                LabeledContent("Location", value: job.location)
            }
            if !job.salary.isEmpty {
                LabeledContent("Salary", value: job.salary)
            }
            if !job.url.isEmpty {
                if let url = URL(string: job.url) {
                    Link(destination: url) {
                        LabeledContent("URL") {
                            Text(url.host ?? job.url)
                                .lineLimit(1)
                        }
                    }
                }
            }
            if let dateApplied = job.dateApplied {
                LabeledContent("Applied") {
                    Text(dateApplied, style: .date)
                }
            }
            LabeledContent("Added") {
                Text(job.dateAdded, style: .relative)
            }
        }
    }

    @ViewBuilder
    private var labelsSection: some View {
        if !job.labels.isEmpty {
            Section("Labels") {
                FlowLayout(spacing: 6) {
                    ForEach(job.labels) { label in
                        Text(label.name)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: label.colorHex)?.opacity(0.2) ?? .gray.opacity(0.2))
                            .foregroundStyle(Color(hex: label.colorHex) ?? .gray)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        Section {
            if job.noteCards.isEmpty {
                Text("No notes yet")
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(job.noteCards) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        if !note.title.isEmpty {
                            Text(note.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        if !note.body.isEmpty {
                            Text(note.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        Text(note.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            HStack {
                Text("Notes")
                Spacer()
                Button {
                    showAddNote = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
    }

    @ViewBuilder
    private var contactsSection: some View {
        if !job.contacts.isEmpty {
            Section("Contacts") {
                ForEach(job.contacts) { contact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if !contact.title.isEmpty {
                            Text(contact.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !contact.email.isEmpty {
                            Text(contact.email)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var interviewsSection: some View {
        if !job.interviews.isEmpty {
            Section("Interviews") {
                ForEach(job.interviews.sorted(by: { $0.round < $1.round })) { interview in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Round \(interview.round): \(interview.type)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let date = interview.date {
                                Text(date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !interview.interviewers.isEmpty {
                                Text(interview.interviewers)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        if interview.completed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tasksSection: some View {
        if !job.tasks.isEmpty {
            Section("Tasks") {
                ForEach(job.tasks) { task in
                    HStack {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? .green : .secondary)
                        Text(task.title)
                            .font(.subheadline)
                            .strikethrough(task.isCompleted)
                    }
                }
            }
        }
    }

    // MARK: - Add Note Sheet

    private var addNoteSheet: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $newNoteTitle)
                TextEditor(text: $newNoteBody)
                    .frame(minHeight: 120)
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddNote = false
                        newNoteTitle = ""
                        newNoteBody = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let note = Note(
                            title: newNoteTitle,
                            body: newNoteBody
                        )
                        store.send(.addNote(job.id, note))
                        showAddNote = false
                        newNoteTitle = ""
                        newNoteBody = ""
                    }
                    .disabled(newNoteTitle.isEmpty && newNoteBody.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: JobStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .foregroundStyle(status.color)
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
