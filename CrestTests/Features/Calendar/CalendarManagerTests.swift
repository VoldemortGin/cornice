import XCTest
@testable import Niya

final class MockEKEventStore {
    var events: [MockCalendarEvent] = []
    func predicateForEvents(start: Date, end: Date, calendarIDs: Set<String>?) -> (start: Date, end: Date, ids: Set<String>?) { (start, end, calendarIDs) }
    func events(matching pred: (start: Date, end: Date, ids: Set<String>?)) -> [MockCalendarEvent] {
        events.filter { e in
            guard e.startDate < pred.end && e.endDate > pred.start else { return false }
            if let ids = pred.ids, !ids.isEmpty { return ids.contains(e.calendarID) }
            return true
        }
    }
}

struct MockCalendarEvent {
    let eventIdentifier: String; let title: String; let startDate: Date; let endDate: Date
    let isAllDay: Bool; let calendarID: String; let calendarTitle: String
    var attendees: [MockAttendee] = []; var status: String = "confirmed"
}

struct MockAttendee { let name: String?; let isCurrentUser: Bool; let status: String }

final class CalendarManagerTests: XCTestCase {
    private var store: MockEKEventStore!
    override func setUp() { super.setUp(); store = MockEKEventStore() }
    override func tearDown() { store = nil; super.tearDown() }

    func test_fetchWithinWindow() {
        let now = Date(); let later = now.addingTimeInterval(86400)
        store.events = [
            MockCalendarEvent(eventIdentifier: "1", title: "Meeting", startDate: now.addingTimeInterval(3600), endDate: now.addingTimeInterval(7200), isAllDay: false, calendarID: "c1", calendarTitle: "W"),
            MockCalendarEvent(eventIdentifier: "2", title: "Future", startDate: now.addingTimeInterval(172800), endDate: now.addingTimeInterval(176400), isAllDay: false, calendarID: "c1", calendarTitle: "W"),
        ]
        let results = store.events(matching: store.predicateForEvents(start: now, end: later, calendarIDs: nil))
        XCTAssertEqual(results.count, 1); XCTAssertEqual(results[0].title, "Meeting")
    }

    func test_sortByStartDate() {
        let now = Date()
        let events = [
            MockCalendarEvent(eventIdentifier: "a", title: "3PM", startDate: now.addingTimeInterval(10800), endDate: now.addingTimeInterval(14400), isAllDay: false, calendarID: "c", calendarTitle: "W"),
            MockCalendarEvent(eventIdentifier: "b", title: "10AM", startDate: now.addingTimeInterval(3600), endDate: now.addingTimeInterval(7200), isAllDay: false, calendarID: "c", calendarTitle: "W"),
            MockCalendarEvent(eventIdentifier: "c", title: "1PM", startDate: now.addingTimeInterval(7200), endDate: now.addingTimeInterval(10800), isAllDay: false, calendarID: "c", calendarTitle: "W"),
        ]
        let sorted = events.sorted { $0.startDate < $1.startDate }
        XCTAssertEqual(sorted[0].title, "10AM"); XCTAssertEqual(sorted[1].title, "1PM"); XCTAssertEqual(sorted[2].title, "3PM")
    }

    func test_filterByCalendar() {
        let now = Date(); let later = now.addingTimeInterval(86400)
        store.events = [
            MockCalendarEvent(eventIdentifier: "1", title: "Work", startDate: now.addingTimeInterval(3600), endDate: now.addingTimeInterval(7200), isAllDay: false, calendarID: "work", calendarTitle: "Work"),
            MockCalendarEvent(eventIdentifier: "2", title: "Personal", startDate: now.addingTimeInterval(7200), endDate: now.addingTimeInterval(10800), isAllDay: false, calendarID: "personal", calendarTitle: "Personal"),
        ]
        let results = store.events(matching: store.predicateForEvents(start: now, end: later, calendarIDs: Set(["work"])))
        XCTAssertEqual(results.count, 1); XCTAssertEqual(results[0].calendarID, "work")
    }

    func test_hideAllDay() {
        let events = [
            MockCalendarEvent(eventIdentifier: "1", title: "Holiday", startDate: Date(), endDate: Date().addingTimeInterval(86400), isAllDay: true, calendarID: "c", calendarTitle: "H"),
            MockCalendarEvent(eventIdentifier: "2", title: "Meeting", startDate: Date().addingTimeInterval(3600), endDate: Date().addingTimeInterval(7200), isAllDay: false, calendarID: "c", calendarTitle: "W"),
        ]
        let filtered = events.filter { !$0.isAllDay }
        XCTAssertEqual(filtered.count, 1); XCTAssertEqual(filtered[0].title, "Meeting")
    }

    func test_declinedEvent_filtered() {
        let e = MockCalendarEvent(eventIdentifier: "1", title: "Declined", startDate: Date(), endDate: Date().addingTimeInterval(3600), isAllDay: false, calendarID: "c", calendarTitle: "W",
                                  attendees: [MockAttendee(name: "Me", isCurrentUser: true, status: "declined")])
        XCTAssertTrue(isDeclined(e))
    }

    func test_acceptedEvent_notDeclined() {
        let e = MockCalendarEvent(eventIdentifier: "1", title: "OK", startDate: Date(), endDate: Date().addingTimeInterval(3600), isAllDay: false, calendarID: "c", calendarTitle: "W",
                                  attendees: [MockAttendee(name: "Me", isCurrentUser: true, status: "accepted")])
        XCTAssertFalse(isDeclined(e))
    }

    func test_noAttendees_notDeclined() {
        let e = MockCalendarEvent(eventIdentifier: "1", title: "Solo", startDate: Date(), endDate: Date().addingTimeInterval(3600), isAllDay: false, calendarID: "c", calendarTitle: "P")
        XCTAssertFalse(isDeclined(e))
    }

    func test_changeNotification_triggers() {
        let exp = expectation(description: "refresh")
        let name = Notification.Name("EKEventStoreChanged_Test")
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in exp.fulfill() }
        NotificationCenter.default.post(name: name, object: nil)
        waitForExpectations(timeout: 2)
    }

    func test_ongoingEvent() {
        let now = Date()
        let e = MockCalendarEvent(eventIdentifier: "1", title: "Now", startDate: now.addingTimeInterval(-1800), endDate: now.addingTimeInterval(1800), isAllDay: false, calendarID: "c", calendarTitle: "W")
        XCTAssertTrue(e.startDate <= now && e.endDate > now)
    }

    func test_futureEvent_notOngoing() {
        let now = Date()
        let e = MockCalendarEvent(eventIdentifier: "1", title: "Later", startDate: now.addingTimeInterval(3600), endDate: now.addingTimeInterval(7200), isAllDay: false, calendarID: "c", calendarTitle: "W")
        XCTAssertFalse(e.startDate <= now && e.endDate > now)
    }

    private func isDeclined(_ e: MockCalendarEvent) -> Bool {
        guard !e.attendees.isEmpty else { return false }
        return e.attendees.contains { $0.isCurrentUser && $0.status == "declined" }
    }
}
