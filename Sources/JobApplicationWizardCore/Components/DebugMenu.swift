#if DEBUG
import SwiftUI
import ComposableArchitecture

// MARK: - Fake Job Data for Testing

/// Generates fake job data with 7+ jobs in the Applied status for testing sticky card behavior.
private func makeFakeJobs() -> [JobApplication] {
    let companies = [
        ("Apple", "Senior iOS Engineer", "Cupertino, CA", "$180,000-$250,000"),
        ("Google", "Staff Software Engineer", "Mountain View, CA", "$220,000-$310,000"),
        ("Meta", "Mobile Engineer", "Menlo Park, CA", "$190,000-$280,000"),
        ("Netflix", "Senior UI Engineer", "Los Gatos, CA", "$200,000-$350,000"),
        ("Stripe", "iOS Platform Engineer", "San Francisco, CA", "$185,000-$260,000"),
        ("Airbnb", "Staff Mobile Engineer", "San Francisco, CA", "$210,000-$300,000"),
        ("Spotify", "Senior iOS Developer", "Remote", "$170,000-$240,000"),
        ("Discord", "Mobile Engineer", "San Francisco, CA", "$175,000-$245,000"),
        ("Figma", "iOS Engineer", "San Francisco, CA", "$165,000-$230,000"),
    ]

    return companies.enumerated().map { index, info in
        var job = JobApplication()
        job.id = UUID(uuidString: "DEADBEEF-0000-0000-0000-\(String(format: "%012d", index))")!
        job.company = info.0
        job.title = info.1
        job.location = info.2
        job.salary = info.3
        job.status = .applied
        job.excitement = min(5, index % 5 + 1)
        job.dateAdded = Date().addingTimeInterval(Double(-index * 86400))
        return job
    }
}

/// Manages the backup/restore lifecycle for debug fake data.
/// Stores the real jobs in memory and restores them on "go back" or app termination.
public final class DebugDataManager: ObservableObject {
    public static let shared = DebugDataManager()

    @Published public var isUsingFakeData = false
    private var realJobsBackup: [JobApplication]?

    public func activateFakeData(store: StoreOf<AppFeature>) {
        guard !isUsingFakeData else { return }
        realJobsBackup = Array(store.jobs)
        store.send(.jobsLoaded(.success(makeFakeJobs())))
        isUsingFakeData = true
    }

    public func restoreRealData(store: StoreOf<AppFeature>) {
        guard isUsingFakeData, let backup = realJobsBackup else { return }
        store.send(.jobsLoaded(.success(backup)))
        realJobsBackup = nil
        isUsingFakeData = false
    }

    /// Call from app termination to ensure real data is persisted.
    public func restoreIfNeeded(store: StoreOf<AppFeature>) {
        if isUsingFakeData {
            restoreRealData(store: store)
        }
    }
}

/// Debug panel opened via Cmd+Shift+D in debug builds.
public struct DebugPanel: View {
    @Bindable public var store: StoreOf<AppFeature>
    @ObservedObject private var debugData = DebugDataManager.shared

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Label("Debug Menu", systemImage: "ladybug")
                .font(DS.Typography.heading3)

            GroupBox("Fake Data") {
                VStack(alignment: .leading, spacing: 8) {
                    if debugData.isUsingFakeData {
                        Label("Using fake data (9 Applied jobs)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)

                        Button("Restore Real Data") {
                            debugData.restoreRealData(store: store)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    } else {
                        Text("Load 9 fake jobs in Applied for testing sticky card scrolling.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Load Fake Jobs") {
                            debugData.activateFakeData(store: store)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("Cuttle AI") {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    LabeledContent("Context") {
                        Text(store.cuttle.currentContext.displayLabel(jobs: Array(store.jobs)))
                    }
                    LabeledContent("Messages") {
                        Text("\(store.cuttle.chatMessages.count)")
                            .monospacedDigit()
                    }
                    LabeledContent("Provider") {
                        Text(store.acpConnection.aiProvider == .acpAgent ? "ACP Agent" : "Claude API")
                    }
                    LabeledContent("Tokens used") {
                        Text("\(store.cuttle.tokenUsage.totalTokens)")
                            .monospacedDigit()
                    }
                    LabeledContent("Drop zones") {
                        Text("\(store.cuttle.dropZones.count)")
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, DS.Spacing.xxs)
            }

            GroupBox("Cuttlefish Circle") {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    JitterCircle()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                }
                .padding(.vertical, DS.Spacing.xxs)
            }

            GroupBox("App State") {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    LabeledContent("Jobs loaded") {
                        Text("\(store.jobs.count)")
                            .monospacedDigit()
                    }
                    LabeledContent("View mode") {
                        Text(store.viewMode.rawValue)
                    }
                    LabeledContent("ACP connected") {
                        Image(systemName: store.acpConnection.isConnected ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(store.acpConnection.isConnected ? DS.Color.success : DS.Color.textSecondary)
                    }
                }
                .padding(.vertical, DS.Spacing.xxs)
            }

            Spacer()
        }
        .padding(DS.Spacing.xl)
        .frame(minWidth: 320, minHeight: 300)
    }
}

/// Menu commands added in debug builds; provides Cmd+Shift+D shortcut.
public struct DebugMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some Commands {
        CommandMenu("Debug") {
            Button("Debug Panel") {
                openWindow(id: "debug")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
#endif
