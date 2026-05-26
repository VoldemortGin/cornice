import SwiftUI

// MARK: - Compact Calendar View

struct CompactCalendarView: View {
    @Bindable var viewModel: CalendarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch viewModel.permissionState {
            case .notDetermined:
                CalendarPermissionPrompt(viewModel: viewModel)
            case .denied, .restricted:
                CalendarDeniedView(viewModel: viewModel)
            case .authorized:
                if viewModel.hasEvents {
                    ForEach(viewModel.compactEvents) { event in
                        CalendarEventRow(event: event)
                    }
                } else {
                    Text("No upcoming events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
    }
}

// MARK: - Expanded Calendar View

struct ExpandedCalendarView: View {
    @Bindable var viewModel: CalendarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch viewModel.permissionState {
            case .notDetermined:
                CalendarPermissionPrompt(viewModel: viewModel)
            case .denied, .restricted:
                CalendarDeniedView(viewModel: viewModel)
            case .authorized:
                if viewModel.hasEvents {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.groupedEvents) { group in
                                Section {
                                    ForEach(group.events) { event in
                                        CalendarEventRow(event: event, showDetails: true)
                                    }
                                } header: {
                                    Text(group.header.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                        .padding(.top, 4)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No upcoming events")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }

                HStack {
                    Spacer()
                    Button("Open in Calendar") {
                        viewModel.openCalendarApp()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(16)
        .onAppear { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
    }
}

// MARK: - Calendar Event Row

struct CalendarEventRow: View {
    let event: CalendarEvent
    var showDetails: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Color dot
            Circle()
                .fill(event.calendarColor)
                .frame(width: 8, height: 8)
                .opacity(event.isOngoing ? 1 : 0.8)

            // Time
            Text(timeText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(event.isOngoing ? .white : .secondary)
                .frame(width: 70, alignment: .trailing)

            // Title
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if showDetails, let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            event.isOngoing
                ? event.calendarColor.opacity(0.15)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title) at \(timeText) from \(event.calendarName)")
    }

    private var timeText: String {
        if event.isAllDay {
            return "All Day"
        }
        return RelativeTimeFormatter.format(for: event)
    }
}

// MARK: - Next Event Indicator (Closed State)

struct NextEventIndicator: View {
    let event: CalendarEvent?

    var body: some View {
        if let event {
            HStack(spacing: 4) {
                Circle()
                    .fill(event.calendarColor)
                    .frame(width: 6, height: 6)
                    .opacity(event.isOngoing ? 1 : 0.8)

                Text(RelativeTimeFormatter.shortRelative(for: event))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white)
            }
        } else {
            Image(systemName: "calendar")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Permission Views

struct CalendarPermissionPrompt: View {
    let viewModel: CalendarViewModel

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundStyle(.blue)

            Text("Calendar Access Needed")
                .font(.caption)
                .foregroundStyle(.white)

            Text("Crest displays your upcoming events in the Dynamic Island.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Grant Access") {
                Task {
                    await viewModel.requestPermission()
                }
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
    }
}

struct CalendarDeniedView: View {
    let viewModel: CalendarViewModel

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("Calendar Access Denied")
                .font(.caption)
                .foregroundStyle(.white)

            Text("Enable calendar access in System Settings to see your events.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                viewModel.openSystemSettings()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
    }
}

// MARK: - Main Calendar View (Wrapper)

struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()
    var isExpanded: Bool = false

    var body: some View {
        if isExpanded {
            ExpandedCalendarView(viewModel: viewModel)
        } else {
            CompactCalendarView(viewModel: viewModel)
        }
    }
}
