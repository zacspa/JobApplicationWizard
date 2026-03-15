#if DEBUG
import SwiftUI
import ComposableArchitecture

/// Debug panel opened via Cmd+Shift+D in debug builds.
public struct DebugPanel: View {
    @Bindable public var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Debug Menu", systemImage: "ladybug")
                .font(.headline)

            if let detail = store.jobDetail {
                GroupBox("AI Assistant") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Mock AI (skips API calls)", isOn: Binding(
                            get: { detail.aiMockMode },
                            set: { newValue in
                                store.send(.jobDetail(.binding(.set(\.aiMockMode, newValue))))
                            }
                        ))

                        LabeledContent("Messages") {
                            Text("\(detail.chatMessages.count)")
                                .monospacedDigit()
                        }
                        LabeledContent("Provider") {
                            Text(detail.acpConnection.aiProvider == .acpAgent ? "ACP Agent" : "Claude API")
                        }
                        LabeledContent("Tokens used") {
                            Text("\(detail.aiTokenUsage.totalTokens)")
                                .monospacedDigit()
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("Select a job to see AI debug options.")
                    .font(.caption).foregroundColor(.secondary)
            }

            GroupBox("Cuttlefish Circle") {
                VStack(alignment: .leading, spacing: 8) {
                    JitterCircle()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .padding(.vertical, 4)
            }

            GroupBox("App State") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Jobs loaded") {
                        Text("\(store.jobs.count)")
                            .monospacedDigit()
                    }
                    LabeledContent("View mode") {
                        Text(store.viewMode.rawValue)
                    }
                    LabeledContent("ACP connected") {
                        Image(systemName: store.acpConnection.isConnected ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(store.acpConnection.isConnected ? .green : .secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .padding(20)
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
