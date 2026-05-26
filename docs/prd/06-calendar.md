# PRD-06: Calendar Widget

## 1. Overview

Calendar widget that surfaces upcoming events from the user's calendars directly in the macOS Dynamic Island. Built on EventKit, it displays the next event in the closed state, a short list in compact view, and a full event browser with mini month calendar in expanded view. Sneak peek alerts notify the user before an event starts.

---

## 2. Goals

- Show upcoming calendar events at a glance without opening Calendar.app.
- Provide timely pre-event alerts through the sneak peek mechanism.
- Respect user privacy: request only necessary calendar permissions, display only selected calendars.
- Handle time zones, all-day events, multi-day events, and recurring events correctly.

## 3. Non-Goals

- Calendar event creation or editing -- events are read-only in v1.
- Reminders integration (EKReminder) -- separate widget in future PRD.
- Third-party calendar sync (Google Calendar API, Microsoft Graph) -- EventKit already aggregates these if the user has configured them in System Settings.
- Video call join buttons (Zoom/Meet links) -- future enhancement.

---

## 4. EventKit Integration

### 4.1 Permission Request

```swift
let store = EKEventStore()

if #available(macOS 14.0, *) {
    // macOS 14 Sonoma+: granular access
    try await store.requestFullAccessToEvents()
} else {
    // macOS 13 and earlier
    store.requestAccess(to: .event) { granted, error in
        // handle result
    }
}
```

### 4.2 Info.plist Entry

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>Niya displays your upcoming calendar events in the Dynamic Island.</string>
```

### 4.3 Permission States

| State | Behavior |
|---|---|
| `.notDetermined` | Show permission prompt with explanation of why access is needed |
| `.fullAccess` / `.authorized` | Normal operation |
| `.denied` | Show "Calendar access denied" with button to open System Settings > Privacy > Calendars |
| `.restricted` | Show "Calendar access restricted by system policy" |
| `.writeOnly` (macOS 17+) | Treat as denied for reading; prompt for full access |

### 4.4 Store Lifecycle

- Single `EKEventStore` instance held by the calendar widget's view model.
- Created on first access, retained for app lifetime.
- On `.EKEventStoreChanged` notification: re-fetch events and refresh UI.

---

## 5. Data Fetching

### 5.1 Event Query

```swift
let now = Date()
let end = Calendar.current.date(byAdding: .hour, value: lookAheadHours, to: now)!
let predicate = store.predicateForEvents(withStart: now, end: end, calendars: selectedCalendars)
let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
```

- `lookAheadHours`: configurable, default 24 hours. Options: 6, 12, 24, 48, 72 hours.
- `selectedCalendars`: user-selected subset of `store.calendars(for: .event)`. Default: all calendars.

### 5.2 Filtering

| Filter | Default | Description |
|---|---|---|
| Calendar selection | All enabled | User picks which calendars to show from a list grouped by source (iCloud, Google, Exchange, etc.) |
| Hide all-day events | false | When true, events where `event.isAllDay == true` are excluded from the list (but can still show in expanded day view) |
| Hide declined events | true | Exclude events where `event.status == .canceled` or attendee self status is `.declined` |

### 5.3 Declined Event Detection

```swift
func isDeclined(_ event: EKEvent) -> Bool {
    guard let attendees = event.attendees else { return false }
    return attendees.contains { attendee in
        attendee.isCurrentUser && attendee.participantStatus == .declined
    }
}
```

### 5.4 Refresh Triggers

| Trigger | Mechanism |
|---|---|
| Calendar database changed | `NotificationCenter.default` observer for `.EKEventStoreChanged` |
| Day rollover (midnight) | Timer that fires at next midnight; recalculates `now` anchor |
| Time zone change | `NSNotification.Name.NSSystemTimeZoneDidChange` observer |
| App becomes active | `NSApplication.didBecomeActiveNotification` -- lightweight refresh |
| Manual pull | User action in expanded view (pull-to-refresh gesture or refresh button) |
| Widget state transition | Re-fetch on transition from hidden -> visible or closed -> open |

---

## 6. Data Model

### 6.1 CalendarEvent (Display Model)

```swift
struct CalendarEvent: Identifiable, Sendable {
    let id: String                    // EKEvent.eventIdentifier
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: Color          // from EKCalendar.cgColor
    let calendarTitle: String
    let location: String?
    let notes: String?
    let url: URL?
    let isRecurring: Bool
    let attendees: [EventAttendee]    // simplified from EKParticipant
    let status: EventStatus

    var isOngoing: Bool {
        let now = Date()
        return startDate <= now && endDate > now
    }

    var isMultiDay: Bool {
        !Calendar.current.isDate(startDate, inSameDayAs: endDate)
    }
}
```

### 6.2 EventAttendee

```swift
struct EventAttendee: Sendable {
    let name: String?
    let email: String?
    let status: EKParticipantStatus   // accepted, declined, tentative, pending
    let isCurrentUser: Bool
    let isOrganizer: Bool
}
```

### 6.3 EventStatus

```swift
enum EventStatus: Sendable {
    case confirmed
    case tentative
    case cancelled
}
```

### 6.4 Mapping from EKEvent

```swift
func mapEvent(_ ekEvent: EKEvent) -> CalendarEvent
```

- Maps `EKEvent` to the display model, stripping EventKit dependencies from the view layer.
- `calendarColor` converted from `CGColor` to SwiftUI `Color`.
- Attendees filtered to include only those with a name or email.

---

## 7. Date & Time Formatting

### 7.1 Relative Time (Close Events)

| Condition | Format | Example |
|---|---|---|
| Starts in < 1 minute | `"Now"` | `"Now"` |
| Starts in 1-59 minutes | `"in X min"` | `"in 15 min"` |
| Starts in 1-6 hours | `"in Xh Ym"` | `"in 2h 30m"` |
| Starts in > 6 hours same day | Time only | `"3:45 PM"` or `"15:45"` |
| Starts tomorrow | `"Tomorrow, TIME"` | `"Tomorrow, 9:00 AM"` |
| Starts further out | `"DAY, TIME"` | `"Wed, 2:00 PM"` |
| Ongoing | `"Now (ends TIME)"` | `"Now (ends 3:30 PM)"` |
| All-day today | `"All Day"` | `"All Day"` |
| All-day future | `"DAY, All Day"` | `"Tomorrow, All Day"` |

### 7.2 System Time Format

- Detect 12h/24h preference: `DateFormatter`'s `dateFormat(fromTemplate: "j", ...)`.
- If template includes `"a"`: 12-hour mode. Otherwise: 24-hour mode.
- All time displays respect this preference.

### 7.3 Smart Grouping (Expanded View)

Events grouped under section headers:

| Condition | Header |
|---|---|
| Today | `"Today"` |
| Tomorrow | `"Tomorrow"` |
| Within this week | Day name: `"Wednesday"` |
| Beyond this week | Full date: `"Jun 15, 2026"` |

---

## 8. Sneak Peek Alerts

### 8.1 Pre-Event Alert

- Fires X minutes before an event starts.
- Configurable lead time: 5, 10, 15, 30 minutes. Default: 15 minutes.
- Content: event title, time, location (if available), calendar color dot.
- Duration: sneak peek remains visible for 5 seconds (standard sneak peek duration).
- Sound: optional, configurable (default: system notification sound).

### 8.2 Alert Scheduling

- On each event fetch, schedule `DispatchWorkItem` for each upcoming event at `startDate - leadTime`.
- Cancel and reschedule on event list refresh.
- Do not alert for:
  - Events that have already started (ongoing).
  - All-day events (unless user enables all-day alerts in settings).
  - Declined events.
  - Events from unselected calendars.

### 8.3 Deduplication

- Track alerted event IDs in a `Set<String>`.
- Clear the set at midnight or when events list refreshes.
- If an event is modified (title/time change detected via `.EKEventStoreChanged`), allow re-alerting.

---

## 9. UI Layouts

### 9.1 Closed State

- **Content**: colored dot (calendar color of next event) + relative time until next event.
- **Format**: `"● 15m"` or `"● 2h"`.
- **If no upcoming events**: show calendar icon only (no dot, no time).
- **If event is ongoing**: pulsing dot + `"Now"`.
- Tapping opens to compact state.

### 9.2 Open State -- Compact

List of next 3-5 events (configurable, default 3):

```
┌──────────────────────────────────┐
│ ● 10:00 AM  Team Standup         │  <- colored dot, time, title
│ ● 12:30 PM  Lunch with Alex      │
│ ●  2:00 PM  Design Review        │
└──────────────────────────────────┘
```

- Ongoing event: highlighted row with subtle background tint matching calendar color.
- Time column: fixed width, right-aligned.
- Title: truncated with ellipsis if too long.
- All-day events: shown at top with `"All Day"` in time column.
- If list is empty: `"No upcoming events"` centered.

### 9.3 Open State -- Expanded

**Left panel -- Event List**:
- Full scrollable list of events within look-ahead window.
- Grouped by day with section headers (see 7.3).
- Each row: calendar color dot, time range (`"10:00 AM - 11:00 AM"`), title, location subtitle.
- Tapping a row shows event detail (see 9.4).

**Right panel -- Mini Month Calendar**:
- Current month grid (7 columns, 5-6 rows).
- Today highlighted with accent circle.
- Days with events: dot indicator below date number.
- Tapping a day filters the event list to that day.
- Swipe/arrows to navigate months.

**Footer**:
- "Open in Calendar" button: `NSWorkspace.shared.open(URL(string: "ical://")!)`.

### 9.4 Event Detail (Expanded Sub-view)

Shown when an event row is tapped in expanded view:

| Field | Content |
|---|---|
| Title | Event title, large font |
| Calendar | Calendar name + color swatch |
| Time | Full date/time range; duration in parentheses |
| Location | Location string; if parseable as address, show "Open in Maps" link |
| Notes | First 3 lines of notes, expandable |
| Attendees | List of attendee names with status icons (checkmark, question, X) |
| URL | Tappable link if event has a URL |
| Action | "Open in Calendar" button -- opens the specific event |

Opening a specific event:

```swift
NSWorkspace.shared.open(URL(string: "ical://ekevent/\(event.eventIdentifier)")!)
```

---

## 10. Empty & Error States

| State | Display |
|---|---|
| Permission not requested | Closed: calendar icon. Open: "Grant calendar access" button with privacy explanation |
| Permission denied | Open: "Calendar access denied" + "Open Settings" button |
| No calendars configured | Open: "No calendars found. Add a calendar account in System Settings." |
| No upcoming events | Closed: calendar icon, no dot. Open: "No upcoming events" with next-fetch-time note |
| EventKit error | Open: "Unable to load events" + retry button. Log error via os_log |
| All events filtered out | Open: "No events match your filters" + link to filter settings |

---

## 11. Settings & Configuration

### 11.1 Widget Settings

| Setting | Type | Default | Options |
|---|---|---|---|
| Enabled | Bool | true | on/off |
| Look-ahead window | Int (hours) | 24 | 6, 12, 24, 48, 72 |
| Events in compact view | Int | 3 | 3, 4, 5 |
| Selected calendars | Set<String> | all calendar IDs | multi-select from available calendars |

### 11.2 Filter Settings

| Setting | Type | Default | Options |
|---|---|---|---|
| Hide all-day events | Bool | false | on/off |
| Hide declined events | Bool | true | on/off |

### 11.3 Alert Settings

| Setting | Type | Default | Options |
|---|---|---|---|
| Pre-event alert enabled | Bool | true | on/off |
| Alert lead time | Int (minutes) | 15 | 5, 10, 15, 30 |
| Alert for all-day events | Bool | false | on/off |
| Alert sound | Bool | true | on/off |

### 11.4 Calendar Selection UI

- List of calendars grouped by account/source (iCloud, Google, Exchange, On My Mac, etc.).
- Each row: color swatch, calendar name, toggle.
- "Select All" / "Deselect All" convenience buttons.
- Persisted as `Set<String>` of `EKCalendar.calendarIdentifier` in UserDefaults.
- On launch: validate stored IDs against current `store.calendars(for: .event)` -- remove stale IDs.

---

## 12. Accessibility

- Event list: each row is an accessibility element with label `"EVENT_TITLE at TIME from CALENDAR_NAME"`.
- Colored dots: paired with `accessibilityLabel` naming the calendar (e.g., `"Work calendar indicator"`).
- Relative time: `accessibilityValue` with full description (e.g., `"starts in 15 minutes"`).
- Mini month calendar: each day cell has `accessibilityLabel` `"DATE, N events"`.
- Sneak peek alert: announced via VoiceOver as `"Upcoming event: TITLE in X minutes"`.
- All interactive elements reachable via keyboard navigation (Tab key).
- Dynamic Type: text sizes adapt to user's accessibility text size preference.

---

## 13. Requirements Table

| ID | Requirement | Priority | Acceptance Criteria |
|---|---|---|---|
| CAL-001 | Request calendar permission with correct API for macOS version | P0 | On macOS 14+: `requestFullAccessToEvents()` called. On macOS 13: `requestAccess(to: .event)` called. Info.plist contains `NSCalendarsFullAccessUsageDescription` |
| CAL-002 | Handle all permission states (not determined, authorized, denied, restricted) | P0 | Each state shows appropriate UI: prompt, normal operation, denied message with Settings link, restricted message |
| CAL-003 | Fetch events within configurable look-ahead window | P0 | Default 24h. Predicate uses `now` as start, `now + lookAheadHours` as end. Changing look-ahead in settings triggers re-fetch |
| CAL-004 | Events sorted by start date ascending | P0 | Unit test: given events at 3pm, 10am, 1pm, result order is 10am, 1pm, 3pm |
| CAL-005 | Observe EKEventStoreChanged and refresh event list | P0 | Integration test: adding event in Calendar.app triggers refresh in Niya within 5 seconds |
| CAL-006 | Refresh on day rollover (midnight) | P1 | At midnight: event list re-fetched with updated `now` anchor; "Today"/"Tomorrow" labels shift correctly |
| CAL-007 | Refresh on time zone change | P1 | Changing system time zone triggers re-fetch; event times displayed in new zone |
| CAL-008 | Filter by selected calendars | P0 | Only events from selected calendars appear; deselecting a calendar removes its events immediately |
| CAL-009 | Option to hide all-day events | P1 | When enabled: events with `isAllDay == true` excluded from closed/compact views; still visible in expanded day view |
| CAL-010 | Option to hide declined events | P1 | When enabled: events where current user's attendee status is `.declined` excluded from all views |
| CAL-011 | Declined event detection via attendee status | P1 | Unit test: event with self as declined attendee returns `isDeclined == true`; event with no attendees returns false |
| CAL-012 | Closed state shows next event's calendar color dot and relative time | P0 | Dot color matches event's calendar CGColor; time formatted per relative time rules (section 7.1) |
| CAL-013 | Closed state shows pulsing dot for ongoing event | P1 | When current time is between event start and end: dot pulses, label shows "Now" |
| CAL-014 | Closed state shows calendar icon only when no events | P1 | When event list is empty: no dot, no time text, only static calendar icon |
| CAL-015 | Compact view shows 3-5 events (configurable) | P0 | Default 3 events shown. Each row: colored dot, time, title. Increasing count to 5 shows 5 rows |
| CAL-016 | Compact view highlights ongoing event | P1 | Row for ongoing event has tinted background matching calendar color at 15% opacity |
| CAL-017 | Compact view shows all-day events at top | P1 | All-day events listed before timed events with "All Day" in time column |
| CAL-018 | Compact view shows empty state when no events | P1 | "No upcoming events" message displayed centered in list area |
| CAL-019 | Expanded view: scrollable event list grouped by day | P1 | Events grouped under "Today", "Tomorrow", day name, or full date headers per rules in 7.3 |
| CAL-020 | Expanded view: mini month calendar with event indicators | P2 | Current month grid rendered; today circled; days with events show dot; tapping day filters list |
| CAL-021 | Expanded view: month navigation (previous/next) | P2 | Arrow buttons or swipe navigates months; calendar grid updates; event dots reflect that month |
| CAL-022 | Expanded view: event detail on row tap | P2 | Tapping event row shows detail with title, calendar, time, location, notes, attendees, URL |
| CAL-023 | Expanded view: "Open in Calendar" button | P1 | Button opens Calendar.app; if tapped from event detail, opens that specific event |
| CAL-024 | Relative time formatting follows rules in section 7.1 | P0 | Unit test for each condition: <1m="Now", 15m="in 15 min", 2h30m="in 2h 30m", tomorrow, further out, ongoing, all-day |
| CAL-025 | Time format respects system 12h/24h preference | P0 | On 12h system: shows "3:45 PM". On 24h system: shows "15:45". No hardcoded format |
| CAL-026 | Sneak peek alert fires at configurable lead time before event | P1 | Default 15 min. Alert content: title, time, location, calendar dot. Alert appears and auto-dismisses after 5s |
| CAL-027 | Sneak peek alert does not fire for all-day events (unless enabled) | P1 | With all-day alerts off: no alert for all-day events. With all-day alerts on: alert fires at configured lead time before midnight of event day |
| CAL-028 | Sneak peek alert does not fire for declined or filtered events | P1 | Events excluded by calendar selection, decline filter, or all-day filter do not trigger alerts |
| CAL-029 | Sneak peek alert deduplication | P1 | Same event does not trigger alert twice per day. Modified event (time change) triggers new alert |
| CAL-030 | Alert scheduling recalculated on event refresh | P1 | Adding/removing/modifying events cancels stale alerts and schedules new ones |
| CAL-031 | Calendar selection persisted in UserDefaults | P1 | After restart: previously selected/deselected calendars retain their state |
| CAL-032 | Stale calendar IDs cleaned on launch | P2 | If a calendar was deleted, its ID is removed from stored selection without crashing |
| CAL-033 | Multi-day events displayed correctly | P1 | Event spanning Mon-Wed: appears under each day's group in expanded view; time shows date range |
| CAL-034 | Recurring events displayed as individual occurrences | P1 | Weekly meeting shows as separate entries for each occurrence within look-ahead window |
| CAL-035 | Location field shows "Open in Maps" link when address-like | P2 | If location string contains a street address or coordinates, tapping "Open in Maps" opens Maps.app with that location |
| CAL-036 | Attendee list shows status icons | P2 | Accepted=checkmark, tentative=question mark, declined=X, pending=dash; icons next to each attendee name |
| CAL-037 | Event detail shows notes (first 3 lines, expandable) | P2 | Notes truncated to 3 lines with "Show more" toggle; expanded shows full notes |
| CAL-038 | Empty state: permission prompt with explanation | P0 | Before permission granted: clear explanation of why access needed + "Grant Access" button |
| CAL-039 | Empty state: denied permission with Settings link | P0 | "Open System Settings" button that deep-links to Privacy > Calendars pane |
| CAL-040 | Accessibility: event rows labeled with title, time, calendar | P1 | VoiceOver reads: "Team Standup at 10:00 AM from Work calendar" for each row |
| CAL-041 | Accessibility: sneak peek announced via VoiceOver | P1 | VoiceOver announces: "Upcoming event: Team Standup in 15 minutes" |
| CAL-042 | Accessibility: mini calendar days labeled with date and event count | P2 | VoiceOver reads: "June 15, 2 events" for each day cell |
| CAL-043 | Keyboard navigation in expanded view | P2 | Tab navigates between event list, mini calendar, and action buttons; Enter activates focused element |

---

## 14. Technical Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| EventKit permission rejected by user | Widget shows no data | Clear pre-prompt explaining value; prominent "Grant Access" in empty state; link to System Settings if denied |
| EKEventStore notifications delayed or missed | Stale event list | Also refresh on `NSApplication.didBecomeActiveNotification` and widget state transitions as backup |
| User has hundreds of calendars / thousands of events | Slow fetch, high memory | Limit predicate window; paginate expanded list; fetch on background queue; cache mapped events |
| All-day events span midnight causing duplicate display | Event appears under wrong day | Use `Calendar.current.isDate(_:inSameDayAs:)` for grouping; handle multi-day all-day events explicitly |
| Calendar.app URL scheme (`ical://`) not available on all macOS versions | "Open in Calendar" fails | Catch `NSWorkspace.open` failure; fall back to opening Calendar.app without deep link |
| Recurring events with exceptions (modified occurrences) | Wrong time/title displayed | Always read from `EKEvent` occurrence properties, not recurrence rule; EventKit handles exceptions internally |
| Time zone changes mid-day (travel) | Events show wrong times | Listen for `NSSystemTimeZoneDidChange`; re-map all event times on zone change |
| Sandboxing restricts EventKit access | Permission prompt never shown | Ensure `com.apple.security.personal-information.calendars` entitlement in entitlements file |

---

## 15. Dependencies

| Dependency | Type | Notes |
|---|---|---|
| EventKit framework | System | Available macOS 10.8+; full access API requires macOS 14+ |
| Dynamic Island widget system (PRD-01/02) | Internal | Closed/compact/expanded state management, sneak peek mechanism |
| Settings infrastructure (PRD-03/04) | Internal | Persisting calendar selection, filter toggles, alert preferences |
| `NSCalendarsFullAccessUsageDescription` in Info.plist | Build config | Required for App Store submission; missing causes silent permission failure |
| `com.apple.security.personal-information.calendars` entitlement | Build config | Required for sandboxed app to access calendars |
