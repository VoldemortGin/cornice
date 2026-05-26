import SwiftUI

/// Larger expansion for detail views (e.g., expanded media player, full system monitor).
struct ExpandedDetailView: View {
    let viewModel: NotchViewModel

    @State private var selectedTab: NotchTab = .home
    @State private var slideDirection: Edge = .trailing

    // Feature view models
    @State private var mediaVM = MediaPlayerViewModel()
    @State private var shelfVM = FileShelfViewModel()
    @State private var clipboardVM = ClipboardHistoryViewModel()
    @State private var monitorVM = SystemMonitorViewModel()
    @State private var calendarVM = CalendarViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBarView(selectedTab: $selectedTab) { oldTab, newTab in
                slideDirection = newTab.index > oldTab.index ? .trailing : .leading
            }

            // Expanded content area
            expandedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            // Collapse button
            collapseButton
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var expandedContent: some View {
        Group {
            switch selectedTab {
            case .home:
                ExpandedMediaView(viewModel: mediaVM)
            case .shelf:
                FileShelfView(viewModel: shelfVM)
            case .clipboard:
                ClipboardHistoryView(viewModel: clipboardVM)
            case .monitor:
                ExpandedMonitorView(viewModel: monitorVM)
            case .calendar:
                ExpandedCalendarView(viewModel: calendarVM)
            }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: slideDirection).combined(with: .opacity),
                removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
            )
        )
        .animation(AnimationConstants.openSpring, value: selectedTab)
        .id(selectedTab)
    }

    private var collapseButton: some View {
        Button {
            viewModel.collapseFromDetail()
        } label: {
            Image(systemName: "chevron.compact.up")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
