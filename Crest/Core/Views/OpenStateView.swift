import SwiftUI

/// The fully expanded notch content with tab bar and feature content area.
struct OpenStateView: View {
    let viewModel: NotchViewModel

    @State private var selectedTab: NotchTab = .home
    @State private var previousTabIndex: Int = 0
    @State private var slideDirection: Edge = .trailing

    // Feature view models (owned here so they persist while open)
    @State private var mediaVM = MediaPlayerViewModel()
    @State private var shelfVM = FileShelfViewModel()
    @State private var clipboardVM = ClipboardHistoryViewModel()
    @State private var monitorVM = SystemMonitorViewModel()
    @State private var calendarVM = CalendarViewModel()
    @State private var quickAppsVM = QuickAppsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar at top
            TabBarView(selectedTab: $selectedTab) { oldTab, newTab in
                slideDirection = newTab.index > oldTab.index ? .trailing : .leading
            }

            // Content area
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .home:
                homeContent
            case .shelf:
                FileShelfView(viewModel: shelfVM)
            case .clipboard:
                ClipboardHistoryView(viewModel: clipboardVM)
            case .monitor:
                CompactMonitorView(viewModel: monitorVM)
            case .calendar:
                CompactCalendarView(viewModel: calendarVM)
            }
        }
        .transition(tabTransition)
        .animation(AnimationConstants.openSpring, value: selectedTab)
        .id(selectedTab)
    }

    private var tabTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: slideDirection).combined(with: .opacity),
            removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Home Tab Content

    @ViewBuilder
    private var homeContent: some View {
        HStack(spacing: 12) {
            // Media player on the left
            CompactMediaView(viewModel: mediaVM)
                .frame(maxWidth: .infinity)

            // Quick apps + widgets on the right
            VStack(spacing: 8) {
                QuickAppsView(viewModel: quickAppsVM)
                Spacer(minLength: 0)
            }
            .frame(width: 180)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
