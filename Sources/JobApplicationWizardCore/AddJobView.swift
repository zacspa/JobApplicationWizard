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

            Form {
                Section("Basic Info") {
                    DSTextField("Company", text: $store.company)
                        .outlinedField("Company", isEmpty: store.company.isEmpty)
                    DSTextField("Job Title", text: $store.title)
                        .outlinedField("Job Title", isEmpty: store.title.isEmpty)
                    DSTextField("Job URL", text: $store.url)
                        .outlinedField("URL", isEmpty: store.url.isEmpty)
                    DSTextField("Location", text: $store.location)
                        .outlinedField("Location", isEmpty: store.location.isEmpty)
                    DSTextField("Salary Range", text: $store.salary)
                        .outlinedField("Salary", isEmpty: store.salary.isEmpty)
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

                Section {
                    Text("Paste the full JD here; it may get taken down later!")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                    DSOutlinedTextEditor("Job Description", text: $store.jobDescription, minHeight: 120)
                } header: {
                    Text("Job Description")
                }

            }
            .formStyle(.grouped)
        }
    }
}
