import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        TabView {
            GeneralSettingsTab(store: store)
                .tabItem { Label("General", systemImage: "gearshape") }
            ClaudeSettingsTab(store: store)
                .tabItem { Label("Claude AI", systemImage: "sparkles") }
            DataSettingsTab(store: store)
                .tabItem { Label("Data", systemImage: "externaldrive") }
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Form {
            Section("Appearance") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default launch view")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("Default view", selection: Binding(
                        get: { store.settings.defaultViewMode },
                        set: { store.send(.defaultViewModeChanged($0)) }
                    )) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - Claude AI Tab

private struct ClaudeSettingsTab: View {
    let store: StoreOf<AppFeature>
    @State private var apiKey = ""
    @State private var showKey = false
    @State private var saved = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
                Button("Save") {
                    store.send(.saveSettingsKey(apiKey))
                    withAnimation {
                        saved = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { saved = false }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Form {
                Section("Claude AI") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Claude API Key")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Used for resume tailoring, cover letters, and interview prep.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Group {
                                if showKey {
                                    TextField("sk-ant-...", text: $apiKey)
                                } else {
                                    SecureField("sk-ant-...", text: $apiKey)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            Button {
                                showKey.toggle()
                            } label: {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Your key is stored in the system Keychain — never written to disk.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 16)
        }
        .onAppear { apiKey = store.claudeAPIKey }
    }
}

// MARK: - Data Tab

private struct DataSettingsTab: View {
    let store: StoreOf<AppFeature>
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section("Import & Export") {
                Button("Export to CSV") {
                    store.send(.exportCSV)
                }
                Button("Import from CSV") {
                    store.send(.importCSV)
                }
            }

            Section("Danger Zone") {
                Button("Reset All Data", role: .destructive) {
                    showResetConfirmation = true
                }
                .alert("Reset All Data?", isPresented: $showResetConfirmation) {
                    Button("Reset", role: .destructive) {
                        store.send(.resetAllData)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all job applications. This cannot be undone.")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - About Tab

private struct AboutSettingsTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "briefcase.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
            VStack(spacing: 6) {
                Text("Job Application Wizard")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Your personal job search command center.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
