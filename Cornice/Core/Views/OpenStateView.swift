import SwiftUI

/// The fully expanded notch content with tab bar and feature content area.
struct OpenStateView: View {
    let viewModel: NotchViewModel
    let featureViewModels: FeatureViewModels

    @State private var selectedTab: NotchTab = .home
    @State private var previousTabIndex: Int = 0
    @State private var slideDirection: Edge = .trailing

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
                FileShelfView(viewModel: featureViewModels.shelf)
            case .clipboard:
                ClipboardHistoryView(viewModel: featureViewModels.clipboard)
            case .monitor:
                CompactMonitorView(viewModel: featureViewModels.monitor)
            case .calendar:
                CompactCalendarView(viewModel: featureViewModels.calendar)
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
            CompactMediaView(viewModel: featureViewModels.media)
                .frame(maxWidth: .infinity)

            // Quick apps + widgets on the right
            VStack(spacing: 8) {
                QuickAppsView(viewModel: featureViewModels.quickApps)
                Spacer(minLength: 0)
            }
            .frame(width: 180)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
