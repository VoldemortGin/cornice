import SwiftUI

/// Displays minimal indicators in the closed notch state.
/// Left: battery indicator, Center: music playing bars, Right: next event time.
struct ClosedStateView: View {
    let viewModel: NotchViewModel

    @State private var mediaVM = MediaPlayerViewModel()
    @State private var calendarVM = CalendarViewModel()
    @State private var monitorVM = SystemMonitorViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Left: battery indicator
            batteryIndicator
                .frame(maxWidth: .infinity, alignment: .leading)

            // Center: music playing indicator
            MusicIndicatorView(isPlaying: mediaVM.isPlaying)

            // Right: next calendar event
            NextEventIndicator(event: calendarVM.nextEvent)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            monitorVM.startMonitoring()
            calendarVM.startObserving()
        }
        .onDisappear {
            monitorVM.stopMonitoring()
            calendarVM.stopObserving()
        }
    }

    @ViewBuilder
    private var batteryIndicator: some View {
        if monitorVM.hasBattery, let battery = monitorVM.batteryInfo {
            HStack(spacing: 3) {
                Image(systemName: batteryIconName(level: battery.level, charging: battery.isCharging))
                    .font(.system(size: 10))
                    .foregroundStyle(monitorVM.batteryColor)

                Text("\(battery.level)%")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else {
            Color.clear.frame(width: 1)
        }
    }

    private func batteryIconName(level: Int, charging: Bool) -> String {
        if charging { return "battery.100percent.bolt" }
        switch level {
        case 0..<13: return "battery.0percent"
        case 13..<38: return "battery.25percent"
        case 38..<63: return "battery.50percent"
        case 63..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
