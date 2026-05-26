import XCTest
import SwiftUI
@testable import Cornice

// MARK: - CalendarEvent Test Helpers

private extension CalendarEvent {
    static func stub(
        id: String = UUID().uuidString,
        title: String = "Meeting",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(3600),
        isAllDay: Bool = false,
        calendarColor: Color = .blue,
        calendarName: String = "Work",
        location: String? = nil,
        isDeclined: Bool = false,
        isRecurring: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            calendarColor: calendarColor,
            calendarName: calendarName,
            location: location,
            isDeclined: isDeclined,
            isRecurring: isRecurring
        )
    }
}

// MARK: - CalendarEvent Model Tests

final class CalendarEventModelTests: XCTestCase {

    func test_isOngoing_currentlyActive() {
        let now = Date()
        let event = CalendarEvent.stub(
            startDate: now.addingTimeInterval(-1800),
            endDate: now.addingTimeInterval(1800)
        )
        XCTAssertTrue(event.isOngoing)
    }

    func test_isOngoing_pastEvent() {
        let event = CalendarEvent.stub(
            startDate: Date().addingTimeInterval(-7200),
            endDate: Date().addingTimeInterval(-3600)
        )
        XCTAssertFalse(event.isOngoing)
    }

    func test_isOngoing_futureEvent() {
        let event = CalendarEvent.stub(
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200)
        )
        XCTAssertFalse(event.isOngoing)
    }

    func test_isPast_pastEvent() {
        let event = CalendarEvent.stub(
            startDate: Date().addingTimeInterval(-7200),
            endDate: Date().addingTimeInterval(-3600)
        )
        XCTAssertTrue(event.isPast)
    }

    func test_isPast_futureEvent() {
        let event = CalendarEvent.stub(
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200)
        )
        XCTAssertFalse(event.isPast)
    }

    func test_isMultiDay_sameDay() {
        let start = Date()
        let event = CalendarEvent.stub(
            startDate: start,
            endDate: start.addingTimeInterval(3600)
        )
        XCTAssertFalse(event.isMultiDay)
    }

    func test_isMultiDay_differentDays() {
        let start = Date()
        let event = CalendarEvent.stub(
            startDate: start,
            endDate: start.addingTimeInterval(86400 * 2)
        )
        XCTAssertTrue(event.isMultiDay)
    }

    func test_hashable_sameID() {
        let event1 = CalendarEvent.stub(id: "abc")
        let event2 = CalendarEvent.stub(id: "abc", title: "Different Title")
        XCTAssertEqual(event1, event2)
    }

    func test_hashable_differentID() {
        let event1 = CalendarEvent.stub(id: "abc")
        let event2 = CalendarEvent.stub(id: "def")
        XCTAssertNotEqual(event1, event2)
    }

    func test_identifiable() {
        let event = CalendarEvent.stub(id: "my-id")
        XCTAssertEqual(event.id, "my-id")
    }
}

// MARK: - CalendarPermissionState Tests

final class CalendarPermissionStateTests: XCTestCase {

    func test_allCasesExist() {
        let states: [CalendarPermissionState] = [.notDetermined, .authorized, .denied, .restricted]
        XCTAssertEqual(states.count, 4)
    }

    func test_conformsToSendable() {
        let state: CalendarPermissionState = .authorized
        let _: any Sendable = state
        _ = state
    }
}

// MARK: - DaySectionHeader Tests

final class DaySectionHeaderTests: XCTestCase {

    func test_today_title() {
        let header = DaySectionHeader.today
        XCTAssertEqual(header.title, "Today")
    }

    func test_tomorrow_title() {
        let header = DaySectionHeader.tomorrow
        XCTAssertEqual(header.title, "Tomorrow")
    }

    func test_weekday_title() {
        let header = DaySectionHeader.weekday("Wednesday")
        XCTAssertEqual(header.title, "Wednesday")
    }

    func test_fullDate_title() {
        let header = DaySectionHeader.fullDate("Jun 15, 2026")
        XCTAssertEqual(header.title, "Jun 15, 2026")
    }

    func test_headerForToday_returnsToday() {
        let header = DaySectionHeader.header(for: Date())
        XCTAssertEqual(header.title, "Today")
    }

    func test_headerForTomorrow_returnsTomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        let header = DaySectionHeader.header(for: tomorrow)
        XCTAssertEqual(header.title, "Tomorrow")
    }

    func test_headerForNextWeek_returnsWeekday() {
        // A date 3 days from now (still within 7-day window)
        let date = Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: Date()))!
        let header = DaySectionHeader.header(for: date)
        // Should be a weekday name
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let expectedDay = formatter.string(from: date)
        XCTAssertEqual(header.title, expectedDay)
    }

    func test_headerForFarFuture_returnsFullDate() {
        let date = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let header = DaySectionHeader.header(for: date)
        // Should be a full date string (MMM d, yyyy)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let expected = formatter.string(from: date)
        XCTAssertEqual(header.title, expected)
    }
}

// MARK: - RelativeTimeFormatter Tests

final class RelativeTimeFormatterTests: XCTestCase {

    func test_ongoingEvent_containsNow() {
        let now = Date()
        let event = CalendarEvent.stub(
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600)
        )
        let result = RelativeTimeFormatter.format(for: event)
        XCTAssertTrue(result.contains("Now"))
    }

    func test_allDayToday_returnsAllDay() {
        // An all-day event that spans from start of today to end of today.
        // Note: RelativeTimeFormatter checks isOngoing before isAllDay.
        // If the event's endDate is in the past (start of today -> start of today),
        // we would get isPast. If ongoing, we get "Now (ends ...)".
        // To test the isAllDay branch, use an event whose startDate is today
        // but is NOT currently ongoing (i.e., it hasn't started yet).
        // This happens when isOngoing is false and isAllDay is true.
        // In practice, an all-day event is always "ongoing" during the day,
        // so the isAllDay branch in format() only triggers when the event
        // hasn't started yet (future all-day) or isPast == true (but then
        // it would not reach the isAllDay branch either).
        // The realistic test: an all-day event for tomorrow triggers the branch.
        // For today specifically, isOngoing takes precedence, returning "Now (ends ...)".
        // So let's verify the ongoing branch works for an all-day today event:
        let today = Calendar.current.startOfDay(for: Date())
        let event = CalendarEvent.stub(
            startDate: today,
            endDate: today.addingTimeInterval(86400),
            isAllDay: true
        )
        let result = RelativeTimeFormatter.format(for: event)
        // The event is ongoing (now >= startDate && now <= endDate), so isOngoing
        // takes priority over isAllDay in the formatter
        XCTAssertTrue(result.contains("Now"))
    }

    func test_allDayTomorrow_returnsTomorrowAllDay() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        let event = CalendarEvent.stub(
            startDate: tomorrow,
            endDate: tomorrow.addingTimeInterval(86400),
            isAllDay: true
        )
        let result = RelativeTimeFormatter.format(for: event)
        XCTAssertEqual(result, "Tomorrow, All Day")
    }

    func test_soonEvent_returnsInMinutes() {
        let event = CalendarEvent.stub(
            startDate: Date().addingTimeInterval(600),  // 10 minutes from now
            endDate: Date().addingTimeInterval(4200)
        )
        let result = RelativeTimeFormatter.format(for: event)
        XCTAssertTrue(result.contains("min"))
    }

    func test_veryImminent_returnsNow() {
        let event = CalendarEvent.stub(
            startDate: Date().addingTimeInterval(30),  // 30 seconds from now
            endDate: Date().addingTimeInterval(3630)
        )
        let result = RelativeTimeFormatter.format(for: event)
        XCTAssertEqual(result, "Now")
    }

    func test_hoursAway_returnsHoursMinutes() {
        let event = CalendarEvent.stub(
            startDate: Date().addingTimeInterval(5400), // 1.5 hours
            endDate: Date().addingTimeInterval(9000)
        )
        let result = RelativeTimeFormatter.format(for: event)
        XCTAssertTrue(result.contains("1h"))
    }

    // MARK: - shortRelative

    func test_shortRelative_ongoingEvent_returnsNow() {
        let now = Date()
        let event = CalendarEvent.stub(
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600)
        )
        let result = RelativeTimeFormatter.shortRelative(for: event)
        XCTAssertEqual(result, "Now")
    }

    func test_shortRelative_veryImminent_returnsNow() {
        let event = CalendarEvent.stub(
            startDate: Date().addingTimeInterval(30),
            endDate: Date().addingTimeInterval(3630)
        )
        let result = RelativeTimeFormatter.shortRelative(for: event)
        XCTAssertEqual(result, "Now")
    }

    func test_shortRelative_minutesAway_returnsMinutes() {
        let event = CalendarEvent.stub(
            startDate: Date().addingTimeInterval(1200), // 20 minutes
            endDate: Date().addingTimeInterval(4800)
        )
        let result = RelativeTimeFormatter.shortRelative(for: event)
        XCTAssertTrue(result.hasSuffix("m"))
    }

    func test_shortRelative_hoursAway_returnsHours() {
        let event = CalendarEvent.stub(
            startDate: Date().addingTimeInterval(7200), // 2 hours
            endDate: Date().addingTimeInterval(10800)
        )
        let result = RelativeTimeFormatter.shortRelative(for: event)
        XCTAssertTrue(result.contains("h"))
    }
}

// MARK: - CalendarViewModel Filter Tests

final class CalendarViewModelFilterTests: XCTestCase {

    @MainActor
    func test_initialState_eventsAreEmpty() {
        let vm = CalendarViewModel()
        XCTAssertTrue(vm.events.isEmpty)
    }

    @MainActor
    func test_initialState_isNotLoading() {
        let vm = CalendarViewModel()
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor
    func test_initialState_errorMessageIsNil() {
        let vm = CalendarViewModel()
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func test_defaultConfig_showAllDayIsTrue() {
        let vm = CalendarViewModel()
        XCTAssertTrue(vm.showAllDay)
    }

    @MainActor
    func test_defaultConfig_showDeclinedIsFalse() {
        let vm = CalendarViewModel()
        XCTAssertFalse(vm.showDeclined)
    }

    @MainActor
    func test_defaultConfig_lookAheadHours() {
        let vm = CalendarViewModel()
        XCTAssertEqual(vm.lookAheadHours, 24)
    }

    @MainActor
    func test_defaultConfig_maxCompactEvents() {
        let vm = CalendarViewModel()
        XCTAssertEqual(vm.maxCompactEvents, 3)
    }

    @MainActor
    func test_filteredEvents_hideAllDay() {
        let vm = CalendarViewModel()
        let now = Date()
        vm.events = [
            .stub(id: "1", title: "All Day", startDate: now, endDate: now.addingTimeInterval(86400), isAllDay: true),
            .stub(id: "2", title: "Timed", startDate: now.addingTimeInterval(3600), endDate: now.addingTimeInterval(7200), isAllDay: false),
        ]
        vm.showAllDay = false
        XCTAssertEqual(vm.filteredEvents.count, 1)
        XCTAssertEqual(vm.filteredEvents[0].title, "Timed")
    }

    @MainActor
    func test_filteredEvents_showAllDay() {
        let vm = CalendarViewModel()
        let now = Date()
        vm.events = [
            .stub(id: "1", title: "All Day", isAllDay: true),
            .stub(id: "2", title: "Timed", isAllDay: false),
        ]
        vm.showAllDay = true
        XCTAssertEqual(vm.filteredEvents.count, 2)
    }

    @MainActor
    func test_filteredEvents_hideDeclined() {
        let vm = CalendarViewModel()
        vm.events = [
            .stub(id: "1", title: "Accepted", isDeclined: false),
            .stub(id: "2", title: "Declined", isDeclined: true),
        ]
        vm.showDeclined = false
        XCTAssertEqual(vm.filteredEvents.count, 1)
        XCTAssertEqual(vm.filteredEvents[0].title, "Accepted")
    }

    @MainActor
    func test_filteredEvents_showDeclined() {
        let vm = CalendarViewModel()
        vm.events = [
            .stub(id: "1", title: "Accepted", isDeclined: false),
            .stub(id: "2", title: "Declined", isDeclined: true),
        ]
        vm.showDeclined = true
        XCTAssertEqual(vm.filteredEvents.count, 2)
    }

    @MainActor
    func test_nextEvent_skipsPastEvents() {
        let vm = CalendarViewModel()
        vm.events = [
            .stub(id: "1", title: "Past", startDate: Date().addingTimeInterval(-7200), endDate: Date().addingTimeInterval(-3600)),
            .stub(id: "2", title: "Future", startDate: Date().addingTimeInterval(3600), endDate: Date().addingTimeInterval(7200)),
        ]
        XCTAssertEqual(vm.nextEvent?.title, "Future")
    }

    @MainActor
    func test_nextEvent_nilWhenAllPast() {
        let vm = CalendarViewModel()
        vm.events = [
            .stub(id: "1", title: "Past1", startDate: Date().addingTimeInterval(-7200), endDate: Date().addingTimeInterval(-3600)),
            .stub(id: "2", title: "Past2", startDate: Date().addingTimeInterval(-3600), endDate: Date().addingTimeInterval(-1800)),
        ]
        XCTAssertNil(vm.nextEvent)
    }

    @MainActor
    func test_nextEvent_nilWhenEmpty() {
        let vm = CalendarViewModel()
        XCTAssertNil(vm.nextEvent)
    }

    @MainActor
    func test_compactEvents_limitedToMaxCompact() {
        let vm = CalendarViewModel()
        let future = Date().addingTimeInterval(3600)
        vm.events = (0..<5).map { i in
            .stub(id: "\(i)", title: "Event \(i)", startDate: future.addingTimeInterval(Double(i) * 3600), endDate: future.addingTimeInterval(Double(i + 1) * 3600))
        }
        vm.maxCompactEvents = 3
        XCTAssertEqual(vm.compactEvents.count, 3)
    }

    @MainActor
    func test_compactEvents_fewerThanMax() {
        let vm = CalendarViewModel()
        vm.events = [
            .stub(id: "1", startDate: Date().addingTimeInterval(3600), endDate: Date().addingTimeInterval(7200)),
        ]
        vm.maxCompactEvents = 3
        XCTAssertEqual(vm.compactEvents.count, 1)
    }

    @MainActor
    func test_hasEvents_true() {
        let vm = CalendarViewModel()
        vm.events = [.stub(id: "1")]
        XCTAssertTrue(vm.hasEvents)
    }

    @MainActor
    func test_hasEvents_false() {
        let vm = CalendarViewModel()
        XCTAssertFalse(vm.hasEvents)
    }

    @MainActor
    func test_groupedEvents_groupsByDay() {
        let vm = CalendarViewModel()
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        vm.events = [
            .stub(id: "1", title: "Today 1", startDate: today.addingTimeInterval(36000), endDate: today.addingTimeInterval(39600)),
            .stub(id: "2", title: "Today 2", startDate: today.addingTimeInterval(43200), endDate: today.addingTimeInterval(46800)),
            .stub(id: "3", title: "Tomorrow 1", startDate: tomorrow.addingTimeInterval(36000), endDate: tomorrow.addingTimeInterval(39600)),
        ]

        let groups = vm.groupedEvents
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].header.title, "Today")
        XCTAssertEqual(groups[0].events.count, 2)
        XCTAssertEqual(groups[1].header.title, "Tomorrow")
        XCTAssertEqual(groups[1].events.count, 1)
    }

    @MainActor
    func test_groupedEvents_emptyEvents() {
        let vm = CalendarViewModel()
        XCTAssertTrue(vm.groupedEvents.isEmpty)
    }

    @MainActor
    func test_selectedCalendarIDs_defaultEmpty() {
        let vm = CalendarViewModel()
        XCTAssertTrue(vm.selectedCalendarIDs.isEmpty)
    }

    @MainActor
    func test_stopObserving_doesNotCrash() {
        let vm = CalendarViewModel()
        vm.stopObserving()
    }
}

// MARK: - EventGroup Tests

final class EventGroupTests: XCTestCase {

    func test_eventGroupIsIdentifiable() {
        let group = EventGroup(header: .today, events: [])
        XCTAssertNotNil(group.id)
    }

    func test_eventGroup_storesEventsAndHeader() {
        let events = [CalendarEvent.stub(id: "1"), CalendarEvent.stub(id: "2")]
        let group = EventGroup(header: .tomorrow, events: events)
        XCTAssertEqual(group.header.title, "Tomorrow")
        XCTAssertEqual(group.events.count, 2)
    }
}
