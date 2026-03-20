import ComposableArchitecture
import CoreGraphics
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

    // MARK: - testValue override

    func testCalendarClientTestValueCanOverrideRequestAccess() async throws {
        // Default testValue returns true
        let defaultResult = try await CalendarClient.testValue.requestAccess()
        XCTAssertTrue(defaultResult)

        // Can be overridden via withDependencies
        var overriddenResult: Bool?
        await withDependencies {
            $0.calendarClient.requestAccess = { false }
        } operation: {
            @Dependency(\.calendarClient) var client
            overriddenResult = try? await client.requestAccess()
        }
        XCTAssertEqual(overriddenResult, false)
    }

    // MARK: - JobDetailFeature: access denied

    @MainActor
    func testCalendarClientTestValueRequestAccessOverridable() async {
        let fetchCalled = LockIsolated(false)
        let interviewId = UUID()
        let job = JobApplication.mock(interviews: [InterviewRound(id: interviewId, round: 1)])

        let store = TestStore(initialState: JobDetailFeature.State(job: job)) {
            JobDetailFeature()
        } withDependencies: {
            $0.calendarClient.requestAccess = { false }
            $0.calendarClient.fetchEvents = { _, _ in
                fetchCalled.setValue(true)
                return []
            }
        }

        await store.send(.linkCalendarEvent(interviewId: interviewId)) {
            $0.showCalendarPicker = true
            $0.calendarPickerInterviewId = interviewId
        }
        await store.receive(\.calendarAccessResult) {
            $0.calendarAccessGranted = false
        }

        XCTAssertFalse(fetchCalled.value, "fetchEvents must not be called when calendar access is denied")
    }

    // MARK: - AppFeature: no calendar permission on launch

    @MainActor
    func testAppFeatureDoesNotRequestCalendarPermissionOnLaunch() async {
        let requestAccessCalled = LockIsolated(false)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.loadJobs = { [] }
            $0.persistenceClient.loadSettings = { AppSettings() }
            $0.keychainClient.loadAPIKey = { "" }
            $0.keychainClient.saveAPIKey = { _ in }
            $0.acpRegistryClient = ACPRegistryClient(fetchAgents: { [] })
            $0.calendarClient.requestAccess = {
                requestAccessCalled.setValue(true)
                return false
            }
        }

        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.jobsLoaded)
        await store.receive(\.settingsLoaded)
        await store.receive(\.saveSettingsKey)

        XCTAssertFalse(requestAccessCalled.value, "Calendar permission must not be requested on app launch")
    }

    // MARK: - cgColorToHex P3 clamping

    func testCgColorToHexClampsP3ComponentsToSRGB() {
        // Extended-sRGB allows component values outside [0, 1]. The old code
        // multiplied those directly by 255, producing values like 382 which
        // overflowed the two-digit hex format. Verify the fix clamps correctly.
        guard let extendedSRGB = CGColorSpace(name: CGColorSpace.extendedSRGB),
              let outOfGamutColor = CGColor(colorSpace: extendedSRGB, components: [1.5, 0.5, -0.2, 1.0]) else {
            XCTFail("Could not create extended-sRGB test color")
            return
        }

        let hex = cgColorToHex(outOfGamutColor)

        XCTAssertEqual(hex.count, 7, "Hex string must be exactly 7 characters (#RRGGBB)")
        XCTAssertTrue(hex.hasPrefix("#"))
        XCTAssertTrue(String(hex.dropFirst()).allSatisfy { $0.isHexDigit }, "All characters after # must be hex digits")
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
