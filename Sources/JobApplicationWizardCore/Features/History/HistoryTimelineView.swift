import SwiftUI
import ComposableArchitecture

public struct HistoryTimelineView: View {
    let store: StoreOf<HistoryFeature>

    public init(store: StoreOf<HistoryFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .font(DS.Typography.heading3)
                Spacer()
                if store.isTimeTraveling {
                    Button("Revert to Here") {
                        store.send(.confirmRevert)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)

                    Button("Cancel") {
                        store.send(.cancelTimeTraveling)
                    }
                    .buttonStyle(DSActionButtonStyle())
                }
                Button {
                    store.send(.toggleTimeline)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Color.controlBackground)

            Divider()

            // Event list
            if store.visibleEvents.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No history yet")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(store.visibleEvents.reversed()) { event in
                            HistoryEventRow(
                                event: event,
                                isRevertTarget: store.revertTargetId == event.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.send(.scrubTo(event.id))
                            }
                        }
                    }
                    .padding(.vertical, DS.Spacing.xxs)
                }
            }
        }
        .frame(width: 280)
        .background(DS.Color.windowBackground)
    }
}

// MARK: - Event Row

private struct HistoryEventRow: View {
    let event: HistoryEvent
    let isRevertTarget: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            // Source badge
            sourceBadge
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.label)
                    .font(DS.Typography.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(event.timestamp.relativeString)
                    .font(DS.Typography.caption2)
                    .foregroundColor(DS.Color.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(isRevertTarget ? Color.orange.opacity(DS.Color.Opacity.wash) : Color.clear)
    }

    @ViewBuilder
    private var sourceBadge: some View {
        switch event.source {
        case .user:
            Image(systemName: "person.fill")
                .font(DS.Typography.caption2)
                .foregroundColor(.blue)
        case .agent:
            Image(systemName: "sparkles")
                .font(DS.Typography.caption2)
                .foregroundColor(.purple)
        case .import:
            Image(systemName: "square.and.arrow.down")
                .font(DS.Typography.caption2)
                .foregroundColor(.green)
        case .system:
            Image(systemName: "gearshape")
                .font(DS.Typography.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Time Travel Banner

/// Overlay banner shown during time-travel mode. Displayed over main content.
public struct TimeTravelBanner: View {
    public init() {}

    public var body: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.orange)
            Text("Time-travel mode: editing disabled. Select an event to revert to, or cancel.")
                .font(DS.Typography.caption)
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(Color.orange.opacity(DS.Color.Opacity.subtle))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.orange.opacity(0.3)),
            alignment: .bottom
        )
    }
}
