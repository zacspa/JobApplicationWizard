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
                    .font(.headline)
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
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button {
                    store.send(.toggleTimeline)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Event list
            if store.visibleEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No history yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Event Row

private struct HistoryEventRow: View {
    let event: HistoryEvent
    let isRevertTarget: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Source badge
            sourceBadge
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.label)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(event.timestamp.relativeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isRevertTarget ? Color.orange.opacity(0.12) : Color.clear)
    }

    @ViewBuilder
    private var sourceBadge: some View {
        switch event.source {
        case .user:
            Image(systemName: "person.fill")
                .font(.caption2)
                .foregroundColor(.blue)
        case .agent:
            Image(systemName: "sparkles")
                .font(.caption2)
                .foregroundColor(.purple)
        case .import:
            Image(systemName: "square.and.arrow.down")
                .font(.caption2)
                .foregroundColor(.green)
        case .system:
            Image(systemName: "gearshape")
                .font(.caption2)
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
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.orange.opacity(0.3)),
            alignment: .bottom
        )
    }
}
