import XCTest
@testable import JobApplicationWizardCore

final class CalendarClientTests: XCTestCase {

    // MARK: - testValue behavior

    func testTestValueRequestAccessReturnsTrue() async throws {
        let result = try await CalendarClient.testValue.requestAccess()
        XCTAssertTrue(result)
    }

    func testTestValueFetchEventsReturnsEmptyArray() async throws {
        let interval = DateInterval(start: Date(), duration: 86400)
        let events = try await CalendarClient.testValue.fetchEvents(interval, nil)
        XCTAssertEqual(events, [])
    }

    func testTestValueFetchCalendarsReturnsEmptyArray() async throws {
        let calendars = try await CalendarClient.testValue.fetchCalendars()
        XCTAssertEqual(calendars, [])
    }

    // MARK: - CalendarEvent initializer

    func testCalendarEventInitializerSetsAllFields() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = Date(timeIntervalSince1970: 1_003_600)
        let event = CalendarEvent(
            id: "test-id-123",
            title: "Phone Screen",
            startDate: start,
            endDate: end,
            location: "Zoom",
            calendarName: "Work",
            calendarColor: "#FF0000",
            isAllDay: false
        )
        XCTAssertEqual(event.id, "test-id-123")
        XCTAssertEqual(event.title, "Phone Screen")
        XCTAssertEqual(event.startDate, start)
        XCTAssertEqual(event.endDate, end)
        XCTAssertEqual(event.location, "Zoom")
        XCTAssertEqual(event.calendarName, "Work")
        XCTAssertEqual(event.calendarColor, "#FF0000")
        XCTAssertFalse(event.isAllDay)
    }

    // MARK: - CalendarInfo initializer

    func testCalendarInfoInitializerSetsAllFields() {
        let info = CalendarInfo(id: "cal-id-456", title: "Personal", colorHex: "#00FF00")
        XCTAssertEqual(info.id, "cal-id-456")
        XCTAssertEqual(info.title, "Personal")
        XCTAssertEqual(info.colorHex, "#00FF00")
    }

    // MARK: - Equatable

    func testCalendarEventEquatableTwoInstancesWithSameFieldsAreEqual() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = Date(timeIntervalSince1970: 1_003_600)
        let event1 = CalendarEvent(
            id: "same-id",
            title: "Interview",
            startDate: start,
            endDate: end,
            location: nil,
            calendarName: "Work",
            calendarColor: "#0000FF",
            isAllDay: false
        )
        let event2 = CalendarEvent(
            id: "same-id",
            title: "Interview",
            startDate: start,
            endDate: end,
            location: nil,
            calendarName: "Work",
            calendarColor: "#0000FF",
            isAllDay: false
        )
        XCTAssertEqual(event1, event2)
    }

    // MARK: - fetchEvents outside test data range

    func testFetchEventsWithDateIntervalOutsideTestDataRangeReturnsEmpty() async throws {
        let futureStart = Date(timeIntervalSinceNow: 86400 * 365)
        let interval = DateInterval(start: futureStart, duration: 86400)
        let events = try await CalendarClient.testValue.fetchEvents(interval, nil)
        XCTAssertEqual(events, [])
    }

    // MARK: - Sendable (compile-time check)

    func testCalendarEventIsSendable() async {
        let event = CalendarEvent(
            id: "sendable-id",
            title: "Onsite",
            startDate: Date(timeIntervalSince1970: 1_000_000),
            endDate: Date(timeIntervalSince1970: 1_003_600),
            location: nil,
            calendarName: "Work",
            calendarColor: "#808080",
            isAllDay: false
        )
        let result = await Task { event }.value
        XCTAssertEqual(result.id, "sendable-id")
    }

    // MARK: - fetchEvent

    func testFetchEventReturnsEventForKnownIdentifierAndNilForUnknown() async throws {
        let knownEvent = CalendarEvent(
            id: "known-id",
            title: "Technical Interview",
            startDate: Date(timeIntervalSince1970: 1_000_000),
            endDate: Date(timeIntervalSince1970: 1_003_600),
            location: nil,
            calendarName: "Work",
            calendarColor: "#FF5500",
            isAllDay: false
        )
        let client = CalendarClient(
            requestAccess: { true },
            fetchEvents: { _, _ in [] },
            fetchEvent: { id in id == "known-id" ? knownEvent : nil },
            fetchCalendars: { [] }
        )

        let found = try await client.fetchEvent("known-id")
        XCTAssertEqual(found, knownEvent)

        let notFound = try await client.fetchEvent("unknown-id")
        XCTAssertNil(notFound)
    }
}
