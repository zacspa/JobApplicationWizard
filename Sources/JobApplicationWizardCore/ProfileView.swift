import SwiftUI

public struct ProfileView: View {
    let onSave: (UserProfile) -> Void
    let onDismiss: () -> Void

    @State private var draft: UserProfile
    @State private var newSkill: String = ""
    @State private var newRole: String = ""

    public init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void, onDismiss: @escaping () -> Void) {
        self._draft = State(initialValue: profile)
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Text("My Profile")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    onSave(draft)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Identity
                    GroupBox(label: Label("Identity", systemImage: "person.fill")) {
                        VStack(spacing: 10) {
                            ProfileField("Name", text: $draft.name)
                            ProfileField("Current Title", text: $draft.currentTitle)
                            ProfileField("Location", text: $draft.location)
                            ProfileField("LinkedIn URL", text: $draft.linkedIn)
                            ProfileField("Website", text: $draft.website)
                        }
                        .padding(.top, 6)
                    }

                    // What I'm Looking For
                    GroupBox(label: Label("What I'm Looking For", systemImage: "target")) {
                        VStack(alignment: .leading, spacing: 10) {
                            // Target Roles
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Target Roles")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TagInputSection(
                                    tags: $draft.targetRoles,
                                    newTag: $newRole,
                                    placeholder: "e.g. iOS Engineer"
                                )
                            }

                            ProfileField("Preferred Salary", text: $draft.preferredSalary, placeholder: "e.g. $150k–$200k")

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Work Preference")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Work Preference", selection: $draft.workPreference) {
                                    ForEach(WorkPreference.allCases, id: \.self) { pref in
                                        Text(pref.rawValue).tag(pref)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }
                        }
                        .padding(.top, 6)
                    }

                    // Skills
                    GroupBox(label: Label("Skills", systemImage: "wrench.and.screwdriver")) {
                        VStack(alignment: .leading, spacing: 6) {
                            TagInputSection(
                                tags: $draft.skills,
                                newTag: $newSkill,
                                placeholder: "e.g. Swift, SwiftUI, TCA"
                            )
                        }
                        .padding(.top, 6)
                    }

                    // Summary
                    GroupBox(label: Label("Summary / Bio", systemImage: "text.quote")) {
                        TextEditor(text: $draft.summary)
                            .font(.body)
                            .frame(minHeight: 70, maxHeight: 100)
                            .scrollContentBackground(.hidden)
                            .padding(.top, 6)
                    }

                    // Resume
                    GroupBox(label: Label("Resume", systemImage: "doc.text")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Paste your resume as plain text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $draft.resume)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 200)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(.top, 6)
                    }

                    // Cover Letter Template
                    GroupBox(label: Label("Cover Letter Template", systemImage: "envelope")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reusable boilerplate Claude will adapt for each job")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $draft.coverLetterTemplate)
                                .font(.body)
                                .frame(minHeight: 150)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Helpers

private struct ProfileField: View {
    let label: String
    @Binding var text: String
    var placeholder: String

    init(_ label: String, text: Binding<String>, placeholder: String? = nil) {
        self.label = label
        self._text = text
        self.placeholder = placeholder ?? label
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct TagInputSection: View {
    @Binding var tags: [String]
    @Binding var newTag: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Existing tags
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption)
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                    }
                }
            }

            // Add new tag
            HStack(spacing: 6) {
                TextField(placeholder, text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTag() }
                Button("Add") { addTag() }
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }
}

