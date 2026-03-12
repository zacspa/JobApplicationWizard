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
                    .font(.headline)
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
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            Form {
                Section("Basic Info") {
                    TextField("Company", text: $store.company)
                    TextField("Job Title", text: $store.title)
                    TextField("Job URL", text: $store.url)
                    TextField("Location", text: $store.location)
                    TextField("Salary Range", text: $store.salary)
                }

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

                Section("Labels") {
                    FlowLayout(spacing: 6) {
                        ForEach(JobLabel.presets) { label in
                            let selected = store.selectedLabelNames.contains(label.name)
                            Button { store.send(.toggleLabel(label.name)) } label: {
                                HStack(spacing: 4) {
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    Text(label.name).font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selected ? label.color.opacity(0.25) : Color.secondary.opacity(0.08))
                                .foregroundColor(selected ? label.color : .secondary)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(selected ? label.color : Color.clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Text("Paste the full JD here — it may get taken down later!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $store.jobDescription)
                        .frame(minHeight: 120)
                        .font(.body)
                } header: {
                    Text("Job Description")
                }

            }
            .formStyle(.grouped)
        }
    }
}
