import SwiftUI
import ComposableArchitecture

public enum SettingsTab: Hashable {
    case general, aiProvider, data, about
}

public extension Notification.Name {
    static let selectSettingsTab = Notification.Name("selectSettingsTab")
}

public struct SettingsView: View {
    @Bindable var store: StoreOf<AppFeature>
    @State private var selectedTab: SettingsTab = .general

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(store: store)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            AIProviderSettingsTab(store: store)
                .tabItem { Label("AI Provider", systemImage: "sparkles") }
                .tag(SettingsTab.aiProvider)
            DataSettingsTab(store: store)
                .tabItem { Label("Data", systemImage: "externaldrive") }
                .tag(SettingsTab.data)
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 480)
        .onReceive(NotificationCenter.default.publisher(for: .selectSettingsTab)) { notif in
            if let tab = notif.object as? SettingsTab {
                selectedTab = tab
            }
        }
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Form {
            Section("Appearance") {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Default launch view")
                        .font(DS.Typography.subheadline)
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
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.lg)
    }
}

// MARK: - AI Provider Tab

private struct AIProviderSettingsTab: View {
    let store: StoreOf<AppFeature>
    @State private var apiKey = ""
    @State private var showKey = false
    @State private var saved = false

    var body: some View {
        VStack(spacing: 0) {
            if store.acpConnection.aiProvider == .claudeAPI {
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
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { saved = false }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.sm)
            }

            Form {
                Section("Provider") {
                    Picker("AI Provider", selection: Binding(
                        get: { store.acpConnection.aiProvider },
                        set: { store.send(.aiProviderChanged($0)) }
                    )) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Agent Actions") {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Picker("When AI proposes changes", selection: Binding(
                            get: { store.settings.agentActionMode },
                            set: { store.send(.agentActionModeChanged($0)) }
                        )) {
                            ForEach(AgentActionMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("\"Apply Immediately\" lets the AI modify job data directly. \"Require Approval\" shows a review sheet first.")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Color.textSecondary)
                    }
                }

                if store.acpConnection.aiProvider == .claudeAPI {
                    Section("Claude API") {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("Claude API Key")
                                .font(DS.Typography.subheadline)
                                .fontWeight(.medium)
                            Text("Used for resume tailoring, cover letters, and interview prep.")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Color.textSecondary)
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
                                .buttonStyle(GhostButtonStyle())
                            }
                            Text("Your key is stored in the system Keychain — never written to disk.")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Color.textSecondary)
                        }
                    }
                } else {
                    Section("ACP Agent") {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                Text("Available Agents")
                                    .font(DS.Typography.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                if store.isLoadingAgents {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Button("Refresh") {
                                    store.send(.fetchACPRegistry)
                                }
                                .buttonStyle(DSActionButtonStyle())
                                .disabled(store.isLoadingAgents)
                            }

                            if store.availableACPAgents.isEmpty && !store.isLoadingAgents {
                                Text("No agents found. Click Refresh to load the registry.")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Color.textSecondary)
                            } else {
                                Picker("Agent", selection: Binding(
                                    get: { store.settings.selectedACPAgentId ?? "" },
                                    set: { store.send(.selectACPAgent($0)) }
                                )) {
                                    Text("Select an agent...").tag("")
                                    ForEach(store.availableACPAgents) { agent in
                                        VStack(alignment: .leading) {
                                            Text(agent.name)
                                            Text(agent.description)
                                                .font(DS.Typography.caption)
                                                .foregroundColor(DS.Color.textSecondary)
                                        }
                                        .tag(agent.id)
                                    }
                                }
                            }
                        }

                        // Connection status
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack(spacing: DS.Spacing.xs) {
                                if store.acpConnection.isConnecting {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Connecting...")
                                        .font(DS.Typography.subheadline)
                                        .foregroundColor(DS.Color.textSecondary)
                                } else {
                                    Circle()
                                        .fill(store.acpConnection.isConnected ? Color.green : Color.gray)
                                        .frame(width: DS.Spacing.sm, height: DS.Spacing.sm)
                                    if let name = store.acpConnection.connectedAgentName {
                                        Text("Connected: \(name)")
                                            .font(DS.Typography.subheadline)
                                    } else {
                                        Text("Disconnected")
                                            .font(DS.Typography.subheadline)
                                            .foregroundColor(DS.Color.textSecondary)
                                    }
                                }
                            }

                            HStack {
                                if store.acpConnection.isConnected {
                                    Button("Disconnect") {
                                        store.send(.disconnectACPAgent)
                                    }
                                    .buttonStyle(DSActionButtonStyle())
                                } else {
                                    Button("Connect") {
                                        store.send(.connectACPAgent)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(store.acpConnection.isConnecting || store.settings.selectedACPAgentId == nil || store.settings.selectedACPAgentId?.isEmpty == true)
                                }
                            }

                            if let error = store.acpConnection.error {
                                Text(error)
                                    .font(DS.Typography.caption)
                                    .foregroundColor(.red)
                                    .onTapGesture {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(error, forType: .string)
                                    }
                                    .help("Click to copy error")
                            }

                            Text("Some agents require Node.js (for npx) or are macOS-only binaries.")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Color.textSecondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, DS.Spacing.lg)
        }
        .onAppear { apiKey = store.claudeAPIKey }
    }
}

// MARK: - Data Tab

private struct DataSettingsTab: View {
    let store: StoreOf<AppFeature>
    @State private var showResetConfirmation = false
    @State private var copiedTemplate = false
    @State private var copiedPrompt = false

    var body: some View {
        Form {
            Section("Import & Export") {
                Button("Export to CSV") {
                    store.send(.exportCSV)
                }
                Button("Import from CSV") {
                    store.send(.importCSV)
                }

                Divider()

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Button("Export Full Backup") {
                        store.send(.exportAll)
                    }
                    Button("Restore from Backup") {
                        store.send(.importAll)
                    }
                    Text("Includes all jobs, chat history, contacts, notes, profile, and settings. API keys are never included.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
            }

            Section("CSV Format") {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Share this format with other tools so they can export files compatible with Job Application Wizard.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(csvHeader)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding(DS.Spacing.sm)
                            .background(DS.Color.textBackground)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
                    }

                    HStack(spacing: DS.Spacing.sm) {
                        Button(copiedTemplate ? "Copied!" : "Copy CSV Template") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(csvTemplateWithSample, forType: .string)
                            copiedTemplate = true
                            Task { @MainActor in try? await Task.sleep(for: .seconds(2)); copiedTemplate = false }
                        }
                        .disabled(copiedTemplate)

                        Button(copiedPrompt ? "Copied!" : "Copy Conversion Prompt") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(csvConversionPrompt, forType: .string)
                            copiedPrompt = true
                            Task { @MainActor in try? await Task.sleep(for: .seconds(2)); copiedPrompt = false }
                        }
                        .disabled(copiedPrompt)
                    }

                    Text("The conversion prompt lets you paste data from any tool into Claude and get back a ready-to-import CSV.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .padding(.vertical, DS.Spacing.xxs)
            }

            Section("Danger Zone") {
                Button("Reset All Data", role: .destructive) {
                    showResetConfirmation = true
                }
                .foregroundColor(.red)
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
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.lg)
        .alert(
            "Replace All Data?",
            isPresented: Binding(
                get: { store.showImportAllConfirm },
                set: { if !$0 { store.send(.cancelImportAll) } }
            )
        ) {
            Button("Replace", role: .destructive) {
                store.send(.confirmImportAll)
            }
            Button("Cancel", role: .cancel) {
                store.send(.cancelImportAll)
            }
        } message: {
            Text("This will replace all current data with the contents of the backup file. This cannot be undone.")
        }
    }
}

// MARK: - CSV Format Constants

private let csvHeader = "ID,Company,Title,URL,Status,DateAdded,DateApplied,Salary,Location,Excitement,IsFavorite,Labels,JobDescription,NoteCards,ResumeUsed,CoverLetter,Contacts,Interviews,HasPDF,PDFPath"

private let csvTemplateWithSample = """
ID,Company,Title,URL,Status,DateAdded,DateApplied,Salary,Location,Excitement,IsFavorite,Labels,JobDescription,NoteCards,ResumeUsed,CoverLetter,Contacts,Interviews,HasPDF,PDFPath
"","Acme Corp","Senior iOS Engineer","https://jobs.acme.com/123","Wishlist","2024-01-15T00:00:00Z","","$150k–$180k","San Francisco, CA","3","false","[]","Full job description here...","[]","","","[]","[]","false",""
"""

private let csvConversionPrompt = """
Convert the job application data below into a CSV with exactly these columns:

ID,Company,Title,URL,Status,DateAdded,DateApplied,Salary,Location,Excitement,IsFavorite,Labels,JobDescription,NoteCards,ResumeUsed,CoverLetter,Contacts,Interviews,HasPDF,PDFPath

Rules:
- ID: leave empty (will be auto-generated on import)
- Status must be one of: Wishlist, Applied, Phone Screen, Interview, Offer, Rejected, Withdrawn
- DateAdded and DateApplied: ISO 8601 format (e.g. 2024-01-15T00:00:00Z), leave DateApplied empty if not applied
- Excitement: integer 1–5
- IsFavorite: true or false
- Labels: JSON array of strings, e.g. ["Remote","High Salary"] — use [] if none
- JobDescription, NoteCards, ResumeUsed, CoverLetter: plain text or JSON as appropriate; use "" if empty
- NoteCards: JSON array, e.g. [{"title":"Notes","body":"..."}] — use [] if none
- Contacts and Interviews: JSON arrays — use [] if none
- HasPDF: false, PDFPath: leave empty
- Wrap every field in double quotes; escape internal double quotes by doubling them ("")

Output only the CSV — no explanation, no markdown fences.

--- DATA TO CONVERT ---
[PASTE YOUR DATA HERE]
"""

// MARK: - About Tab

private struct AboutSettingsTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            Image(systemName: "briefcase.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
            VStack(spacing: DS.Spacing.xs) {
                Text("Job Application Wizard")
                    .font(DS.Typography.heading1)
                    .fontWeight(.bold)
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Color.textSecondary)
                Text("Your personal job search command center.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Color.textSecondary)
                    .padding(.top, DS.Spacing.xxs)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxxl)
    }
}
