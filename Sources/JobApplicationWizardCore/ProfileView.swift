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
                    .font(DS.Typography.heading2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    onSave(draft)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.lg)
            .background(DS.Color.windowBackground)

            Divider()

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    // Identity
                    GroupBox(label: Label("Identity", systemImage: "person.fill")) {
                        VStack(spacing: DS.Spacing.md) {
                            DSTextField("Name", text: $draft.name)
                                .outlinedField("Name", isEmpty: draft.name.isEmpty)
                            DSTextField("Current Title", text: $draft.currentTitle)
                                .outlinedField("Current Title", isEmpty: draft.currentTitle.isEmpty)
                            DSTextField("Location", text: $draft.location)
                                .outlinedField("Location", isEmpty: draft.location.isEmpty)
                            DSTextField("LinkedIn URL", text: $draft.linkedIn)
                                .outlinedField("LinkedIn", isEmpty: draft.linkedIn.isEmpty)
                            DSTextField("Website", text: $draft.website)
                                .outlinedField("Website", isEmpty: draft.website.isEmpty)
                        }
                        .padding(.top, DS.Spacing.xs)
                    }

                    // What I'm Looking For
                    GroupBox(label: Label("What I'm Looking For", systemImage: "target")) {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            TagInputSection(
                                label: "Target Roles",
                                tags: $draft.targetRoles,
                                newTag: $newRole,
                                placeholder: "e.g. iOS Engineer"
                            )

                            DSTextField("e.g. $150k-$200k", text: $draft.preferredSalary)
                                .outlinedField("Preferred Salary", isEmpty: draft.preferredSalary.isEmpty)

                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Work Preference")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Color.textSecondary)
                                Picker("Work Preference", selection: $draft.workPreference) {
                                    ForEach(WorkPreference.allCases, id: \.self) { pref in
                                        Text(pref.rawValue).tag(pref)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }
                        }
                        .padding(.top, DS.Spacing.xs)
                    }

                    // Skills
                    GroupBox(label: Label("Skills", systemImage: "wrench.and.screwdriver")) {
                        TagInputSection(
                            label: "Skills",
                            tags: $draft.skills,
                            newTag: $newSkill,
                            placeholder: "e.g. Swift, SwiftUI, TCA"
                        )
                        .padding(.top, DS.Spacing.xs)
                    }

                    // Summary
                    GroupBox(label: Label("Summary / Bio", systemImage: "text.quote")) {
                        DSOutlinedTextEditor("Summary", text: $draft.summary, minHeight: 70)
                            .padding(.top, DS.Spacing.xs)
                    }

                    // Resume
                    GroupBox(label: Label("Resume", systemImage: "doc.text")) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("Paste your resume as plain text")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Color.textSecondary)
                            DSOutlinedTextEditor("Resume", text: $draft.resume, minHeight: 200)
                        }
                        .padding(.top, DS.Spacing.xs)
                    }

                    // Cover Letter Template
                    GroupBox(label: Label("Cover Letter Template", systemImage: "envelope")) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("Reusable boilerplate Claude will adapt for each job")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Color.textSecondary)
                            DSOutlinedTextEditor("Cover Letter", text: $draft.coverLetterTemplate, minHeight: 150)
                        }
                        .padding(.top, DS.Spacing.xs)
                    }
                }
                .padding(DS.Spacing.xl)
            }
        }
    }
}

// MARK: - Helpers

private struct TagInputSection: View {
    var label: String
    @Binding var tags: [String]
    @Binding var newTag: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if !tags.isEmpty {
                FlowLayout(spacing: DS.Spacing.xs) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: DS.Spacing.xxs) {
                            Text(tag)
                                .font(DS.Typography.caption)
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(Color.accentColor.opacity(DS.Color.Opacity.wash))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                    }
                }
            }

            DSTextField(placeholder, text: $newTag, onSubmit: addTag)
                .outlinedField(label, isEmpty: newTag.isEmpty)
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }
}
