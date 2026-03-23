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
            VStack(spacing: DS.Spacing.xs) {
                HStack {
                    Text("Job Tracker")
                        .font(DS.Typography.heading2)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.xs) {
                    StatBubble(value: store.stats.total, label: "Total", color: .blue)
                    StatBubble(value: store.stats.active, label: "Active", color: .orange)
                    StatBubble(value: store.stats.interviews, label: "Interviews", color: .cyan)
                    StatBubble(value: store.stats.offers, label: "Offers", color: .green)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.sm)
            }
            .background(DS.Color.controlBackground)

            Divider()

            // View mode
            HStack(spacing: DS.Spacing.xxs) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button {
                        store.send(.viewModeChanged(mode))
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                            .font(DS.Typography.caption)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .frame(maxWidth: .infinity)
                            .background(store.viewMode == mode ? Color.accentColor.opacity(DS.Color.Opacity.tint) : Color.clear)
                            .foregroundColor(store.viewMode == mode ? .accentColor : DS.Color.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Spacing.sm)

            Divider()

            // My Profile card
            Button { store.send(.showProfileTapped) } label: {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Profile")
                            .fontWeight(.semibold)
                        Text(store.settings.userProfile.name.isEmpty
                             ? "Set up for AI assistance"
                             : store.settings.userProfile.name)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .padding(DS.Spacing.md)
                .background(DS.Color.controlBackground)
                .cornerRadius(DS.Radius.medium)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .cuttleDockable(context: .global)

            Spacer()

            Divider()

            // Bottom: settings + import + export
            HStack(spacing: DS.Spacing.sm) {
                SettingsLink {
                    Image(systemName: "gear")
                        .foregroundColor(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Settings")

                Spacer()

                Button {
                    store.send(.importCSV)
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Import from CSV")

                Button {
                    store.send(.exportCSV)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Export to CSV")
            }
            .padding(DS.Spacing.md)
            .background(DS.Color.controlBackground)
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
                .font(DS.Typography.heading1)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(DS.Typography.caption2)
                .foregroundColor(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
        .background(color.opacity(DS.Color.Opacity.subtle))
        .cornerRadius(DS.Radius.medium)
    }
}
