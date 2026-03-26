import SwiftUI
import ComposableArchitecture
import JobApplicationShared
import UniformTypeIdentifiers

struct SettingsViewiOS: View {
    let store: StoreOf<iOSAppFeature>

    @State private var showImportPicker = false

    var body: some View {
        NavigationStack {
            List {
                profileSection
                syncSection
                statsSection
                dataSection
            }
            .navigationTitle("Settings")
            .alert("Import Error", isPresented: Binding(
                get: { store.importError != nil },
                set: { if !$0 { store.send(.dismissImportError) } }
            )) {
                Button("OK") { store.send(.dismissImportError) }
            } message: {
                Text(store.importError ?? "")
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        store.send(.importData(data))
                    }
                case .failure:
                    break
                }
            }
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            let profile = store.settings.userProfile
            if !profile.name.isEmpty {
                LabeledContent("Name", value: profile.name)
            }
            if !profile.currentTitle.isEmpty {
                LabeledContent("Title", value: profile.currentTitle)
            }
            if !profile.location.isEmpty {
                LabeledContent("Location", value: profile.location)
            }
            if profile.name.isEmpty && profile.currentTitle.isEmpty && profile.location.isEmpty {
                Text("No profile configured. Set up your profile on the desktop app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsSection: some View {
        Section("Stats") {
            LabeledContent("Total Jobs", value: "\(store.jobs.count)")

            let active = store.jobs.filter {
                $0.status != .rejected && $0.status != .withdrawn
            }.count
            LabeledContent("Active", value: "\(active)")

            let interviews = store.jobs.flatMap(\.interviews).filter { !$0.completed }.count
            LabeledContent("Pending Interviews", value: "\(interviews)")
        }
    }

    private var syncSection: some View {
        Section("Google Drive Sync") {
            if store.isSyncEnabled {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connected")
                    Spacer()
                    if store.isSyncing {
                        ProgressView()
                    }
                }

                if let lastSync = store.lastSyncDate {
                    LabeledContent("Last Synced") {
                        Text(lastSync, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    store.send(.syncNow)
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(store.isSyncing)

                Button(role: .destructive) {
                    store.send(.syncSignOut)
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    store.send(.syncSignIn)
                } label: {
                    Label("Sign in with Google", systemImage: "globe")
                }
            }

            if let error = store.syncError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            ShareLink(
                "Export JSON Backup",
                item: exportData(),
                preview: SharePreview("JobApplicationWizard Backup", image: Image(systemName: "doc.zipper"))
            )

            Button {
                showImportPicker = true
            } label: {
                Label("Import JSON Backup", systemImage: "square.and.arrow.down")
            }
        }
    }

    private func exportData() -> Data {
        store.send(.exportRequested)
        return SharedPersistenceClient.liveValue.exportAllData(
            Array(store.jobs),
            store.settings
        )
    }
}
