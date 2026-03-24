import SwiftUI
import ComposableArchitecture

public struct AddJobView: View {
    @Bindable var store: StoreOf<AddJobFeature>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<AddJobFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Job Application")
                    .font(DS.Typography.heading3)
                Spacer()
                Button("Cancel") {
                    store.send(.cancelTapped)
                    dismiss()
                }
                Button("Save") {
                    store.send(.saveTapped)
                    dismiss()
                }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canSave)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Color.windowBackground)

            Divider()

            HStack {
                Spacer()
                Picker("", selection: $store.entryMode) {
                    ForEach(EntryMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 260)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Form {
                if store.entryMode == .aiImport {
                    aiImportSection
                } else {
                    basicInfoSection
                    statusSection
                    labelsSection
                    jobDescriptionSection
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - AI Import Section

    @ViewBuilder
    private var aiImportSection: some View {
        Section {
            HStack {
                TextField("Job URL (optional)", text: $store.url)
                Button {
                    store.send(.createFromPasteTapped)
                } label: {
                    if store.isParsing || store.isImporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Extract", systemImage: "sparkles")
                    }
                }
                .disabled(!store.canParse)
            }
            if store.isImporting {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(store.importProgress == .fetching ? "Fetching job data..." : "Enriching with AI...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text("Paste the job listing below and let AI extract the details.")
                .font(.caption)
                .foregroundColor(.secondary)
            TextEditor(text: $store.pastedText)
                .frame(minHeight: 150)
                .font(.body)
            if let error = store.parseError ?? store.importError {
                HStack {
                    Image(systemName: error.contains("requires login") ? "lock.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        store.send(.dismissParseError)
                        store.send(.dismissImportError)
                    }
                    .font(.caption)
                }
            }
        } header: {
            Text("AI Import")
        }
    }

    // MARK: - Basic Info Section

    @ViewBuilder
    private var basicInfoSection: some View {
        Section("Basic Info") {
            DSTextField("Company", text: $store.company)
                .outlinedField("Company", isEmpty: store.company.isEmpty)
            DSTextField("Job Title", text: $store.title)
                .outlinedField("Job Title", isEmpty: store.title.isEmpty)
            if store.entryMode == .manual {
                DSTextField("Job URL", text: $store.url)
                    .outlinedField("URL", isEmpty: store.url.isEmpty)
            }
            DSTextField("Location", text: $store.location)
                .outlinedField("Location", isEmpty: store.location.isEmpty)
            DSTextField("Salary Range", text: $store.salary)
                .outlinedField("Salary", isEmpty: store.salary.isEmpty)
        }
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        Section("Status & Excitement") {
            Picker("Status", selection: $store.status) {
                ForEach(JobStatus.allCases) { s in
                    Label(s.rawValue, systemImage: s.icon).tag(s)
                }
            }
            HStack {
                Text("Excitement")
                Spacer()
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= store.excitement ? "star.fill" : "star")
                        .foregroundColor(.orange)
                        .onTapGesture { store.send(.setExcitement(i)) }
                }
            }
        }
    }

    // MARK: - Labels Section

    @ViewBuilder
    private var labelsSection: some View {
        Section("Labels") {
            FlowLayout(spacing: DS.Spacing.xs) {
                ForEach(JobLabel.presets) { label in
                    let selected = store.selectedLabelNames.contains(label.name)
                    Button { store.send(.toggleLabel(label.name)) } label: {
                        HStack(spacing: DS.Spacing.xxs) {
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Text(label.name).font(DS.Typography.caption)
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(selected ? label.color.opacity(DS.Color.Opacity.strong) : Color.secondary.opacity(DS.Color.Opacity.subtle))
                        .foregroundColor(selected ? label.color : .secondary)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(selected ? label.color : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, DS.Spacing.xxs)
        }
    }

    // MARK: - Job Description Section

    @ViewBuilder
    private var jobDescriptionSection: some View {
        Section {
            Text("Paste the full JD here; it may get taken down later!")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)
            DSOutlinedTextEditor("Job Description", text: $store.jobDescription, minHeight: 120)
        } header: {
            Text("Job Description")
        }
    }
}
