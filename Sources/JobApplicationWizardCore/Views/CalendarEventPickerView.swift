import SwiftUI

// MARK: - CalendarEventPickerView

public struct CalendarEventPickerView: View {
    public let events: [CalendarEvent]
    @Binding public var searchQuery: String
    public let onSelect: (CalendarEvent) -> Void
    public let onCancel: () -> Void
    public var isAccessDenied: Bool = false

    public init(
        events: [CalendarEvent],
        searchQuery: Binding<String>,
        onSelect: @escaping (CalendarEvent) -> Void,
        onCancel: @escaping () -> Void,
        isAccessDenied: Bool = false
    ) {
        self.events = events
        self._searchQuery = searchQuery
        self.onSelect = onSelect
        self.onCancel = onCancel
        self.isAccessDenied = isAccessDenied
    }

    // Exposed for testing
    public var filteredEvents: [CalendarEvent] {
        guard !searchQuery.isEmpty else { return events }
        return events.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
    }

    // Exposed for testing: returns (dayStart, events) pairs sorted chronologically
    public var eventsGroupedByDay: [(Date, [CalendarEvent])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event in
            cal.startOfDay(for: event.startDate)
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { $0.startDate < $1.startDate }) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
        }
        .frame(width: 360, height: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DS.Color.textSecondary)
            DSTextField("Search events...", text: $searchQuery)
        }
        .outlinedField("Search", isEmpty: searchQuery.isEmpty)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Color.controlBackground)
    }

    @ViewBuilder
    private var content: some View {
        if isAccessDenied {
            permissionDeniedView
        } else if filteredEvents.isEmpty {
            emptyStateView
        } else {
            eventList
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(DS.Color.textSecondary)
            Text("Calendar access required")
                .font(DS.Typography.heading3)
            Text("Grant access in System Settings to link calendar events to interview rounds.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Open System Settings") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security")!
                )
            }
            .buttonStyle(DSActionButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 36))
                .foregroundColor(DS.Color.textSecondary)
            Text(
                searchQuery.isEmpty
                    ? "No upcoming events"
                    : "No events match \"\(searchQuery)\""
            )
            .font(DS.Typography.subheadline)
            .foregroundColor(DS.Color.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var eventList: some View {
        List {
            ForEach(eventsGroupedByDay, id: \.0) { day, dayEvents in
                Section(header: sectionHeader(for: day)) {
                    ForEach(dayEvents) { event in
                        Button { onSelect(event) } label: {
                            CalendarEventRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func sectionHeader(for day: Date) -> some View {
        Text(day, format: .dateTime.weekday(.wide).month(.wide).day().year())
            .font(DS.Typography.footnote)
            .fontWeight(.semibold)
            .foregroundColor(DS.Color.textSecondary)
            .textCase(nil)
    }
}

// MARK: - CalendarEventRow

public struct CalendarEventRow: View {
    public let event: CalendarEvent

    public init(event: CalendarEvent) {
        self.event = event
    }

    // Exposed as static for unit testing
    public static func timeRangeText(for event: CalendarEvent) -> String {
        if event.isAllDay { return "All day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }

    public var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(Color(hex: event.calendarColor) ?? .gray)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(DS.Typography.subheadline)
                    .lineLimit(1)
                HStack(spacing: DS.Spacing.xxs) {
                    Text(Self.timeRangeText(for: event))
                        .font(DS.Typography.footnote)
                        .foregroundColor(DS.Color.textSecondary)
                    Text("·")
                        .font(DS.Typography.footnote)
                        .foregroundColor(DS.Color.textSecondary)
                    Text(event.calendarName)
                        .font(DS.Typography.footnote)
                        .foregroundColor(DS.Color.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
