import EventKit
import Foundation
import ComposableArchitecture

// MARK: - Value Types

public struct CalendarEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: String              // EKEvent.eventIdentifier
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var location: String?
    public var calendarName: String
    public var calendarColor: String   // Hex color from EKCalendar.cgColor
    public var isAllDay: Bool

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        calendarName: String,
        calendarColor: String,
        isAllDay: Bool
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.calendarName = calendarName
        self.calendarColor = calendarColor
        self.isAllDay = isAllDay
    }
}

public struct CalendarInfo: Codable, Equatable, Identifiable, Sendable {
    public var id: String              // EKCalendar.calendarIdentifier
    public var title: String
    public var colorHex: String

    public init(id: String, title: String, colorHex: String) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
    }
}

// MARK: - CalendarClient

public struct CalendarClient {
    public var requestAccess: @Sendable () async throws -> Bool
    public var fetchEvents: @Sendable (DateInterval, String?) async throws -> [CalendarEvent]
    public var fetchEvent: @Sendable (String) async throws -> CalendarEvent?
    public var fetchCalendars: @Sendable () async throws -> [CalendarInfo]

    public init(
        requestAccess: @escaping @Sendable () async throws -> Bool,
        fetchEvents: @escaping @Sendable (DateInterval, String?) async throws -> [CalendarEvent],
        fetchEvent: @escaping @Sendable (String) async throws -> CalendarEvent?,
        fetchCalendars: @escaping @Sendable () async throws -> [CalendarInfo]
    ) {
        self.requestAccess = requestAccess
        self.fetchEvents = fetchEvents
        self.fetchEvent = fetchEvent
        self.fetchCalendars = fetchCalendars
    }
}

// MARK: - CGColor Helper

func cgColorToHex(_ cgColor: CGColor) -> String {
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let converted = cgColor.converted(to: srgb, intent: .defaultIntent, options: nil),
          let components = converted.components, components.count >= 3 else {
        return "#808080"
    }
    let r = Int(min(max(components[0], 0), 1) * 255)
    let g = Int(min(max(components[1], 0), 1) * 255)
    let b = Int(min(max(components[2], 0), 1) * 255)
    return String(format: "#%02X%02X%02X", r, g, b)
}

// MARK: - Live Value

extension CalendarClient: DependencyKey {
    public static var liveValue: CalendarClient {
        let store = EKEventStore()

        return CalendarClient(
            requestAccess: {
                try await store.requestFullAccessToEvents()
            },
            fetchEvents: { interval, calendarID in
                let calendars: [EKCalendar]?
                if let calendarID {
                    let all = store.calendars(for: .event)
                    let filtered = all.filter { $0.calendarIdentifier == calendarID }
                    calendars = filtered.isEmpty ? nil : filtered
                } else {
                    calendars = nil
                }
                let predicate = store.predicateForEvents(
                    withStart: interval.start,
                    end: interval.end,
                    calendars: calendars
                )
                return store.events(matching: predicate).map { event in
                    CalendarEvent(
                        id: event.eventIdentifier,
                        title: event.title ?? "",
                        startDate: event.startDate,
                        endDate: event.endDate,
                        location: event.location,
                        calendarName: event.calendar?.title ?? "",
                        calendarColor: event.calendar.map { cgColorToHex($0.cgColor) } ?? "#808080",
                        isAllDay: event.isAllDay
                    )
                }
            },
            fetchEvent: { identifier in
                guard let event = store.event(withIdentifier: identifier) else { return nil }
                return CalendarEvent(
                    id: event.eventIdentifier,
                    title: event.title ?? "",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    calendarName: event.calendar?.title ?? "",
                    calendarColor: event.calendar.map { cgColorToHex($0.cgColor) } ?? "#808080",
                    isAllDay: event.isAllDay
                )
            },
            fetchCalendars: {
                store.calendars(for: .event).map { calendar in
                    CalendarInfo(
                        id: calendar.calendarIdentifier,
                        title: calendar.title,
                        colorHex: cgColorToHex(calendar.cgColor)
                    )
                }
            }
        )
    }
}

// MARK: - Test Value

extension CalendarClient: TestDependencyKey {
    public static let testValue = CalendarClient(
        requestAccess: { true },
        fetchEvents: { _, _ in [] },
        fetchEvent: { _ in nil },
        fetchCalendars: { [] }
    )
}

// MARK: - Dependency Values

extension DependencyValues {
    public var calendarClient: CalendarClient {
        get { self[CalendarClient.self] }
        set { self[CalendarClient.self] = newValue }
    }
}
