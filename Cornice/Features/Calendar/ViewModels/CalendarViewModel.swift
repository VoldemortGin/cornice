import SwiftUI
import EventKit
import Combine
import os

private let log = Logger(subsystem: "com.cornice.app", category: "calendar")

@MainActor
@Observable
final class CalendarViewModel {
    // MARK: - Public State

    var events: [CalendarEvent] = []
    var permissionState: CalendarPermissionState = .notDetermined
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Configuration

    var lookAheadHours: Int = 24
    var showAllDay: Bool = true
    var showDeclined: Bool = false
    var selectedCalendarIDs: Set<String> = []
    var maxCompactEvents: Int = 3

    // MARK: - Computed

    var nextEvent: CalendarEvent? {
        filteredEvents.first { !$0.isPast }
    }

    var filteredEvents: [CalendarEvent] {
        events.filter { event in
            if !showAllDay && event.isAllDay { return false }
            if !showDeclined && event.isDeclined { return false }
            return true
        }
    }

    var compactEvents: [CalendarEvent] {
        Array(filteredEvents.prefix(maxCompactEvents))
    }

    var groupedEvents: [EventGroup] {
        let calendar = Calendar.current
        var groups: [String: [CalendarEvent]] = [:]
        var groupOrder: [String] = []

        for event in filteredEvents {
            let dayKey = calendar.startOfDay(for: event.startDate).description
            if groups[dayKey] == nil {
                groups[dayKey] = []
                groupOrder.append(dayKey)
            }
            groups[dayKey]?.append(event)
        }

        return groupOrder.compactMap { key in
            guard let events = groups[key], let firstEvent = events.first else { return nil }
            let header = DaySectionHeader.header(for: firstEvent.startDate)
            return EventGroup(header: header, events: events)
        }
    }

    var hasEvents: Bool { !filteredEvents.isEmpty }

    // MARK: - Private

    private let service = CalendarService()
    private var refreshTimer: Timer?
    private var midnightTimer: Timer?
    private var timeZoneObserver: NSObjectProtocol?
    private var appActiveObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        permissionState = service.permissionState

        service.onEventsChanged = { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        setupObservers()
    }

    // MARK: - Permission

    func requestPermission() async {
        let granted = await service.requestAccess()
        permissionState = service.permissionState
        if granted {
            refresh()
        }
        log.info("Calendar permission result: \(granted)")
    }

    // MARK: - Refresh

    func refresh() {
        guard permissionState == .authorized else {
            permissionState = service.permissionState
            return
        }

        isLoading = true
        errorMessage = nil

        let calendars: [EKCalendar]?
        if selectedCalendarIDs.isEmpty {
            calendars = nil // Use all calendars
        } else {
            calendars = service.calendars(withIdentifiers: selectedCalendarIDs)
        }

        events = service.fetchEvents(lookAheadHours: lookAheadHours, calendars: calendars)
        isLoading = false
        log.info("Calendar refreshed: \(self.events.count) events")
    }

    // MARK: - Lifecycle

    func startObserving() {
        refresh()
        scheduleMidnightRefresh()
    }

    func stopObserving() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        midnightTimer?.invalidate()
        midnightTimer = nil
    }

    // MARK: - Available Calendars

    func availableCalendars() -> [(id: String, name: String, color: Color)] {
        service.availableCalendars().map { cal in
            let color: Color
            if let cgColor = cal.cgColor {
                color = Color(cgColor: cgColor)
            } else {
                color = .blue
            }
            return (id: cal.calendarIdentifier, name: cal.title, color: color)
        }
    }

    // MARK: - Private Setup

    private func setupObservers() {
        timeZoneObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        appActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    private func scheduleMidnightRefresh() {
        midnightTimer?.invalidate()
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) else {
            return
        }
        let interval = tomorrow.timeIntervalSinceNow

        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.scheduleMidnightRefresh()
            }
        }
    }

    // MARK: - Actions

    func openCalendarApp() {
        CalendarService.openCalendarApp()
    }

    func openSystemSettings() {
        CalendarService.openSystemSettings()
    }
}
