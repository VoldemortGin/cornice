import SwiftUI

/// Shows temporary notification content in the sneak peek state.
/// Content varies by event type: track change, volume/brightness HUD, battery, calendar.
struct SneakPeekView: View {
    let event: SneakPeekEvent

    var body: some View {
        HStack(spacing: 12) {
            eventIcon
                .frame(width: 24, height: 24)

            switch event {
            case .volume(let level):
                hudBar(value: level, color: .white, icon: volumeIcon(for: level))
            case .brightness(let level):
                hudBar(value: level, color: .yellow.opacity(0.9), icon: "sun.max.fill")
            default:
                textContent
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Icon

    @ViewBuilder
    private var eventIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
    }

    private var iconName: String {
        switch event {
        case .trackChange: return "music.note"
        case .volume(let level): return volumeIcon(for: level)
        case .brightness: return "sun.max.fill"
        case .battery(_, let isCharging): return isCharging ? "battery.100percent.bolt" : "battery.75percent"
        case .calendarEvent: return "calendar"
        case .timerCompleted: return "timer"
        }
    }

    // MARK: - Text Content (for non-HUD events)

    @ViewBuilder
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
    }

    private var title: String {
        switch event {
        case .trackChange(let title, _): return title
        case .volume(let level): return "Volume \(Int(level * 100))%"
        case .brightness(let level): return "Brightness \(Int(level * 100))%"
        case .battery(let pct, _): return "Battery \(pct)%"
        case .calendarEvent(let title, _): return title
        case .timerCompleted(let label): return label
        }
    }

    private var subtitle: String? {
        switch event {
        case .trackChange(_, let artist): return artist.isEmpty ? nil : artist
        case .battery(_, let isCharging): return isCharging ? "Charging" : "Low Battery"
        case .calendarEvent(_, let minutes): return "in \(minutes) min"
        default: return nil
        }
    }

    // MARK: - HUD Bar (for volume/brightness)

    @ViewBuilder
    private func hudBar(value: Double, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)

                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * value), height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)

            Text("\(Int(value * 100))%")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func volumeIcon(for level: Double) -> String {
        if level <= 0 { return "speaker.slash.fill" }
        if level < 0.33 { return "speaker.wave.1.fill" }
        if level < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
