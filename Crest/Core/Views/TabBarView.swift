import SwiftUI

/// Horizontal row of tab icons displayed at the top of the open state.
struct TabBarView: View {
    @Binding var selectedTab: NotchTab
    var onTabChanged: ((NotchTab, NotchTab) -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NotchTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.04))
    }

    private func tabButton(for tab: NotchTab) -> some View {
        Button {
            let previous = selectedTab
            if selectedTab != tab {
                selectedTab = tab
                onTabChanged?(previous, tab)
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.5))
                    .frame(width: 24, height: 24)

                // Selection indicator dot
                Circle()
                    .fill(selectedTab == tab ? Color.white : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NotchTab Enum

enum NotchTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case shelf
    case clipboard
    case monitor
    case calendar

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .shelf: return "tray.full.fill"
        case .clipboard: return "clipboard.fill"
        case .monitor: return "gauge.with.dots.needle.33percent"
        case .calendar: return "calendar"
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .shelf: return "Shelf"
        case .clipboard: return "Clipboard"
        case .monitor: return "Monitor"
        case .calendar: return "Calendar"
        }
    }

    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}
