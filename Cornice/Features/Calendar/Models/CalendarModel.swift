import SwiftUI
import EventKit

// MARK: - Calendar Event

struct CalendarEvent: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: Color
    let calendarName: String
    let location: String?
    let isDeclined: Bool
    let isRecurring: Bool

    var isOngoing: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var isPast: Bool {
        Date() > endDate
    }

    var isMultiDay: Bool {
        !Calendar.current.isDate(startDate, inSameDayAs: endDate)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Calendar Permission State

enum CalendarPermissionState: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

// MARK: - Relative Time Formatting

enum RelativeTimeFormatter {
    static func format(for event: CalendarEvent) -> String {
        let now = Date()

        if event.isOngoing {
            let endFormatted = timeString(for: event.endDate)
            return "Now (ends \(endFormatted))"
        }

        if event.isAllDay {
            if Calendar.current.isDateInToday(event.startDate) {
                return "All Day"
            } else if Calendar.current.isDateInTomorrow(event.startDate) {
                return "Tomorrow, All Day"
            } else {
                let dayName = dayString(for: event.startDate)
                return "\(dayName), All Day"
            }
        }

        let interval = event.startDate.timeIntervalSince(now)

        if interval < 60 {
            return "Now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "in \(minutes) min"
        } else if interval < 21600 { // 6 hours
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes > 0 {
                return "in \(hours)h \(minutes)m"
            }
            return "in \(hours)h"
        } else if Calendar.current.isDateInToday(event.startDate) {
            return timeString(for: event.startDate)
        } else if Calendar.current.isDateInTomorrow(event.startDate) {
            return "Tomorrow, \(timeString(for: event.startDate))"
        } else {
            return "\(shortDayString(for: event.startDate)), \(timeString(for: event.startDate))"
        }
    }

    static func shortRelative(for event: CalendarEvent) -> String {
        let now = Date()

        if event.isOngoing {
            return "Now"
        }

        let interval = event.startDate.timeIntervalSince(now)

        if interval < 60 {
            return "Now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        }
    }

    private static func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private static func shortDayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Day Section Grouping

enum DaySectionHeader {
    case today
    case tomorrow
    case weekday(String)   // e.g. "Wednesday"
    case fullDate(String)  // e.g. "Jun 15, 2026"

    var title: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .weekday(let name): return name
        case .fullDate(let date): return date
        }
    }

    static func header(for date: Date) -> DaySectionHeader {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInTomorrow(date) {
            return .tomorrow
        } else {
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: .now))!
            if date < endOfWeek {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return .weekday(formatter.string(from: date))
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                return .fullDate(formatter.string(from: date))
            }
        }
    }
}

struct EventGroup: Identifiable {
    let id = UUID()
    let header: DaySectionHeader
    let events: [CalendarEvent]
}
