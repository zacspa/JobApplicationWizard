import XCTest
import SwiftUI
@testable import JobApplicationWizardCore

final class CalendarEventPickerViewTests: XCTestCase {

    // MARK: - Helpers

    private func makeEvent(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date = Date(),
        endDate: Date? = nil,
        isAllDay: Bool = false,
        calendarName: String = "Calendar"
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate ?? startDate.addingTimeInterval(3600),
            calendarName: calendarName,
            calendarColor: "#FF0000",
            isAllDay: isAllDay
        )
    }

    private func makePickerView(
        events: [CalendarEvent],
        searchQuery: String = ""
    ) -> CalendarEventPickerView {
        var query = searchQuery
        return CalendarEventPickerView(
            events: events,
            searchQuery: Binding(get: { query }, set: { query = $0 }),
            onSelect: { _ in },
            onCancel: {}
        )
    }

    // MARK: - filteredEvents: empty query

    func testFilteredEventsReturnsAllWhenSearchQueryIsEmpty() {
        let events = [makeEvent(title: "Phone Screen"), makeEvent(title: "Technical Interview")]
        let view = makePickerView(events: events, searchQuery: "")
        XCTAssertEqual(view.filteredEvents.count, 2)
    }

    // MARK: - filteredEvents: substring match

    func testFilteredEventsFiltersByTitleSubstringCaseInsensitive() {
        let events = [
            makeEvent(title: "Phone Screen"),
            makeEvent(title: "Technical Interview"),
            makeEvent(title: "PHONE CALL")
        ]
        let view = makePickerView(events: events, searchQuery: "phone")
        XCTAssertEqual(view.filteredEvents.count, 2)
        XCTAssertTrue(view.filteredEvents.allSatisfy {
            $0.title.localizedCaseInsensitiveContains("phone")
        })
    }

    // MARK: - filteredEvents: no match

    func testFilteredEventsReturnsEmptyWhenQueryMatchesNothing() {
        let events = [makeEvent(title: "Phone Screen"), makeEvent(title: "Technical Interview")]
        let view = makePickerView(events: events, searchQuery: "zzz")
        XCTAssertTrue(view.filteredEvents.isEmpty)
    }

    // MARK: - grouping by day

    func testEventsOnSameDayGroupedIntoOneSection() {
        let cal = Calendar.current
        let baseDate = cal.startOfDay(for: Date())
        let morning = baseDate.addingTimeInterval(9 * 3600)
        let afternoon = baseDate.addingTimeInterval(14 * 3600)
        let events = [
            makeEvent(id: "a", title: "Morning", startDate: morning),
            makeEvent(id: "b", title: "Afternoon", startDate: afternoon)
        ]
        let view = makePickerView(events: events)
        XCTAssertEqual(view.eventsGroupedByDay.count, 1)
        XCTAssertEqual(view.eventsGroupedByDay[0].1.count, 2)
    }

    // MARK: - multi-day sorted chronologically

    func testEventsOnMultipleDaysSortedChronologically() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = cal.date(byAdding: .day, value: 2, to: today)!

        let events = [
            makeEvent(id: "c", title: "Day After", startDate: dayAfter),
            makeEvent(id: "a", title: "Today", startDate: today),
            makeEvent(id: "b", title: "Tomorrow", startDate: tomorrow)
        ]
        let view = makePickerView(events: events)
        let days = view.eventsGroupedByDay.map { $0.0 }
        XCTAssertEqual(days, days.sorted())
    }

    func testEventsWithinDaySortedByStartTime() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let late = base.addingTimeInterval(15 * 3600)
        let early = base.addingTimeInterval(8 * 3600)
        let events = [
            makeEvent(id: "late", title: "Late", startDate: late),
            makeEvent(id: "early", title: "Early", startDate: early)
        ]
        let view = makePickerView(events: events)
        let section = view.eventsGroupedByDay[0].1
        XCTAssertEqual(section[0].id, "early")
        XCTAssertEqual(section[1].id, "late")
    }

    // MARK: - All-day event time text

    func testAllDayEventDisplaysAllDayText() {
        let event = makeEvent(title: "All Day Event", isAllDay: true)
        let text = CalendarEventRow.timeRangeText(for: event)
        XCTAssertEqual(text, "All day")
    }

    func testTimedEventDisplaysTimeRange() {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 14; comps.minute = 0
        let start = cal.date(from: comps)!
        let end = start.addingTimeInterval(3600) // 3:00 PM
        let event = makeEvent(title: "Timed", startDate: start, endDate: end, isAllDay: false)
        let text = CalendarEventRow.timeRangeText(for: event)
        XCTAssertTrue(text.contains("-"), "Expected time range with '-', got: \(text)")
        XCTAssertFalse(text == "All day")
    }

    // MARK: - Empty state

    func testEmptyStateWhenFilteredEventsIsEmpty() {
        let events = [makeEvent(title: "Phone Screen")]
        let view = makePickerView(events: events, searchQuery: "zzz")
        XCTAssertTrue(view.filteredEvents.isEmpty)
    }
}
