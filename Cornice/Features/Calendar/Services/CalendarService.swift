import EventKit
import SwiftUI
import os

private let log = Logger(subsystem: "com.cornice.app", category: "calendar")

// MARK: - Protocol

protocol CalendarProviding: AnyObject {
    var permissionState: CalendarPermissionState { get }
    var onEventsChanged: (() -> Void)? { get set }
    func requestAccess() async -> Bool
    func fetchEvents(lookAheadHours: Int, calendars: [EKCalendar]?) -> [CalendarEvent]
    func availableCalendars() -> [EKCalendar]
    func calendars(withIdentifiers ids: Set<String>) -> [EKCalendar]
}

// MARK: - Concrete Implementation

final class CalendarService: CalendarProviding {
    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?

    var onEventsChanged: (() -> Void)?

    init() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            log.info("Calendar store changed, triggering refresh")
            self?.onEventsChanged?()
        }
    }

    deinit {
        if let observer = changeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Permission

    var permissionState: CalendarPermissionState {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            return .notDetermined
        case .fullAccess, .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted, .writeOnly:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    func requestAccess() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    store.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        } catch {
            log.error("Calendar permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Fetching Events

    func fetchEvents(lookAheadHours: Int = 24, calendars: [EKCalendar]? = nil) -> [CalendarEvent] {
        guard permissionState == .authorized else {
            log.warning("Calendar not authorized, cannot fetch events")
            return []
        }

        let now = Date()
        guard let end = Calendar.current.date(byAdding: .hour, value: lookAheadHours, to: now) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendars)
        let ekEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        return ekEvents.map { mapEvent($0) }
    }

    // MARK: - Calendar List

    func availableCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
    }

    func calendars(withIdentifiers ids: Set<String>) -> [EKCalendar] {
        store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
    }

    // MARK: - Event Mapping

    private func mapEvent(_ ekEvent: EKEvent) -> CalendarEvent {
        let color: Color
        if let cgColor = ekEvent.calendar.cgColor {
            color = Color(cgColor: cgColor)
        } else {
            color = .blue
        }

        return CalendarEvent(
            id: ekEvent.eventIdentifier,
            title: ekEvent.title ?? "Untitled",
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            isAllDay: ekEvent.isAllDay,
            calendarColor: color,
            calendarName: ekEvent.calendar.title,
            location: ekEvent.location,
            isDeclined: isDeclined(ekEvent),
            isRecurring: ekEvent.hasRecurrenceRules
        )
    }

    // MARK: - Declined Detection

    private func isDeclined(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }
        return attendees.contains { attendee in
            attendee.isCurrentUser && attendee.participantStatus == .declined
        }
    }

    // MARK: - Open Calendar App

    static func openCalendarApp() {
        if let url = URL(string: "ical://") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
