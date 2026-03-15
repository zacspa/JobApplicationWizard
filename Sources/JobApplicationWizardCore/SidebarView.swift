import SwiftUI
import ComposableArchitecture

public struct SidebarView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Stats
            VStack(spacing: 6) {
                HStack {
                    Text("Job Tracker")
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    StatBubble(value: store.stats.total, label: "Total", color: .blue)
                    StatBubble(value: store.stats.active, label: "Active", color: .orange)
                    StatBubble(value: store.stats.interviews, label: "Interviews", color: .cyan)
                    StatBubble(value: store.stats.offers, label: "Offers", color: .green)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // View mode
            HStack(spacing: 4) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button {
                        store.send(.viewModeChanged(mode))
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(store.viewMode == mode ? Color.accentColor.opacity(0.15) : Color.clear)
                            .foregroundColor(store.viewMode == mode ? .accentColor : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)

            Divider()

            // My Profile card
            Button { store.send(.showProfileTapped) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Profile")
                            .fontWeight(.semibold)
                        Text(store.settings.userProfile.name.isEmpty
                             ? "Set up for AI assistance"
                             : store.settings.userProfile.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Spacer()

            Divider()

            // Bottom: settings + import + export
            HStack(spacing: 8) {
                SettingsLink {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")

                Spacer()

                Button {
                    store.send(.importCSV)
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Import from CSV")

                Button {
                    store.send(.exportCSV)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Export to CSV")
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

struct StatBubble: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
}
