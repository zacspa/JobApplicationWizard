import SwiftUI
import ComposableArchitecture

public struct ContentView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.openWindow) private var openWindow
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } content: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                StatusFilterBar(store: store)
                Divider()
                Group {
                    switch store.viewMode {
                    case .kanban: KanbanView(store: store)
                    case .list:   ListView(store: store)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 420, ideal: 540)
        } detail: {
            if let detailStore = store.scope(state: \.jobDetail, action: \.jobDetail) {
                JobDetailView(store: detailStore)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 450)
                    .id(store.selectedJobID)
            } else {
                ContentUnavailableView(
                    "Select a Job",
                    systemImage: "briefcase",
                    description: Text("Choose a job application to view details, or add a new one.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if columnVisibility != .all {
                    SettingsLink {
                        Image(systemName: "gear").padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")

                    Button { store.send(.importCSV) } label: {
                        Image(systemName: "square.and.arrow.down").padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Import from CSV")

                    Button { store.send(.exportCSV) } label: {
                        Image(systemName: "square.and.arrow.up").padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Export to CSV")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { store.showOnboarding },
            set: { if !$0 { store.send(.dismissOnboarding) } }
        )) {
            OnboardingView(store: store)
        }
        .sheet(isPresented: Binding(
            get: { store.showProfile },
            set: { if !$0 { store.send(.dismissProfile) } }
        )) {
            ProfileView(
                profile: store.settings.userProfile,
                onSave: { store.send(.saveProfile($0)) },
                onDismiss: { store.send(.dismissProfile) }
            )
            .frame(minWidth: 560, minHeight: 700)
        }
        .onAppear { store.send(.onAppear) }
    }

    var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search companies, titles, locations...", text: $store.searchQuery.sending(\.searchQueryChanged))
                    .textFieldStyle(.plain)
                if !store.searchQuery.isEmpty {
                    Button { store.send(.searchQueryChanged("")) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Spacer()

            Button {
                store.send(.prepareAddJob)
                openWindow(id: "add-job")
            } label: {
                Label("Add Job", systemImage: "plus")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Status Filter Bar

struct StatusFilterBar: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterPill(label: "All", count: store.jobs.count,
                           selected: store.filterStatus == nil) {
                    store.send(.filterStatusChanged(nil))
                }
                ForEach(JobStatus.allCases) { status in
                    FilterPill(label: status.rawValue,
                               count: store.jobs.filter { $0.status == status }.count,
                               selected: store.filterStatus == status) {
                        store.send(.filterStatusChanged(status))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct FilterPill: View {
    let label: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(selected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .font(.caption)
            .fontWeight(selected ? .semibold : .regular)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .foregroundColor(selected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(selected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .controlSize(.small)
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Welcome to Job Application Wizard")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Your personal job search command center")
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(icon: "square.grid.3x2.fill", color: .blue,
                    title: "Kanban Board",
                    desc: "Drag jobs through your pipeline: Wishlist → Applied → Interview → Offer")
                FeatureRow(icon: "doc.text.fill", color: .orange,
                    title: "Save Job Descriptions",
                    desc: "Paste the full JD before it gets taken down. It'll be there when you need it.")
                FeatureRow(icon: "person.2.fill", color: .purple,
                    title: "Track Contacts",
                    desc: "Log recruiters, hiring managers, and referrals with notes and LinkedIn links")
                FeatureRow(icon: "sparkles", color: .pink,
                    title: "Claude AI Assistant",
                    desc: "Tailor your resume, generate cover letters, and prep for interviews with AI")
                FeatureRow(icon: "square.and.arrow.up.fill", color: .green,
                    title: "Export to CSV",
                    desc: "Export your data anytime — you always own it")
            }

            Button("Get Started") {
                store.send(.dismissOnboarding)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return)
        }
        .padding(40)
        .frame(width: 520)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
