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
        ZStack {
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
                        case .kanban: KanbanView(
                            store: store,
                            onDocumentDrop: { jobId, urls in store.send(.documentDropped(jobId, urls)) },
                            processingJobIds: store.processingDocumentJobIds
                        )
                        case .list: ListView(store: store) { jobId, urls in
                            store.send(.documentDropped(jobId, urls))
                        }
                        }
                    }
                }
                .navigationSplitViewColumnWidth(min: 420, ideal: 540)
            } detail: {
                if let detailStore = store.scope(state: \.jobDetail, action: \.jobDetail) {
                    JobDetailView(store: detailStore, calendarStore: store.scope(state: \.calendar, action: \.calendar))
                        .modifier(DetailColumnWidth())
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

            // Cuttle overlay
            GeometryReader { geo in
                CuttleView(store: store.scope(state: \.cuttle, action: \.cuttle))
                    .onChange(of: geo.size) { _, newSize in
                        store.send(.cuttle(.windowSizeChanged(newSize)))
                    }
                    .onAppear {
                        store.send(.cuttle(.windowSizeChanged(geo.size)))
                    }
            }

            // Cuttle onboarding overlay
            if store.cuttleOnboarding.isActive {
                CuttleOnboardingOverlay(
                    store: store.scope(state: \.cuttleOnboarding, action: \.cuttleOnboarding),
                    cuttlePosition: store.cuttle.position,
                    cuttleIsExpanded: store.cuttle.isExpanded,
                    windowSize: store.cuttle.windowSize,
                    dropZones: store.cuttle.dropZones
                )
            }
        }
        .coordinateSpace(name: "cuttle-window")
        .onPreferenceChange(DropZonePreferenceKey.self) { zones in
            store.send(.cuttle(.dropZonesUpdated(zones)))
        }
        .environment(\.cuttlePendingContext, store.cuttle.pendingContext)
        .environment(\.cuttleCurrentContext, store.cuttle.currentContext)
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
        .overlay(alignment: .bottom) {
            if let toast = store.calendar.syncToast {
                Text(toast)
                    .padding(.horizontal, DS.Spacing.lg).padding(.vertical, DS.Spacing.md)
                    .background(DS.Glass.chrome, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                    .padding(.bottom, DS.Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring, value: store.calendar.syncToast)
        .alert("Data Error", isPresented: Binding(
            get: { store.saveError != nil },
            set: { if !$0 { store.send(.dismissSaveError) } }
        )) {
            Button("OK") { store.send(.dismissSaveError) }
        } message: {
            Text(store.saveError ?? "")
        }
    }

    var toolbar: some View {
        HStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DS.Color.textSecondary)
                DSTextField("Search companies, titles, locations...", text: Binding(
                    get: { store.searchQuery },
                    set: { store.send(.searchQueryChanged($0)) }
                ))
                if !store.searchQuery.isEmpty {
                    Button { store.send(.searchQueryChanged("")) } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
            .outlinedField("Search", isEmpty: store.searchQuery.isEmpty)

            Spacer()

            Button { store.send(.undo) } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(GhostButtonStyle())
            .opacity(store.undoStack.isEmpty ? 0.3 : 1.0)
            .disabled(store.undoStack.isEmpty)
            .keyboardShortcut("z", modifiers: .command)
            .help("Undo")

            Button { store.send(.redo) } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(GhostButtonStyle())
            .opacity(store.redoStack.isEmpty ? 0.3 : 1.0)
            .disabled(store.redoStack.isEmpty)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .help("Redo")

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
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Color.windowBackground)
    }
}

// MARK: - Status Filter Bar

struct StatusFilterBar: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                FilterPill(label: "All", count: store.jobs.count,
                           selected: store.filterStatus == nil) {
                    store.send(.filterStatusChanged(nil))
                }
                .cuttleDockable(context: .global)
                ForEach(JobStatus.allCases) { status in
                    FilterPill(label: status.rawValue,
                               count: store.jobs.filter { $0.status == status }.count,
                               selected: store.filterStatus == status) {
                        store.send(.filterStatusChanged(status))
                    }
                    .cuttleDockable(context: .status(status))
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(DS.Color.windowBackground)
    }
}

struct FilterPill: View {
    let label: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xxs) {
                Text(label)
                Text("\(count)")
                    .font(DS.Typography.caption2)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 1)
                    .background(selected ? Color.white.opacity(DS.Color.Opacity.strong) : Color.secondary.opacity(DS.Color.Opacity.wash))
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(PillButtonStyle(isSelected: selected))
        .controlSize(.small)
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Image(systemName: "briefcase.fill")
                .font(DS.Typography.displayLarge)
                .foregroundColor(.accentColor)

            VStack(spacing: DS.Spacing.sm) {
                Text("Welcome to Job Application Wizard")
                    .font(DS.Typography.heading1)
                    .fontWeight(.bold)
                Text("Your personal job search command center")
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
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
        .padding(DS.Spacing.huge)
        .frame(width: 520)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(DS.Typography.heading2)
                .foregroundColor(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(desc).font(DS.Typography.caption).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Detail Column Width

/// Fixed detail column width now that the AI panel is no longer inline.
private struct DetailColumnWidth: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationSplitViewColumnWidth(min: 460, ideal: 600, max: .infinity)
    }
}
