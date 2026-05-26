import SwiftUI

/// Larger expansion for detail views (e.g., expanded media player, full system monitor).
struct ExpandedDetailView: View {
    let viewModel: NotchViewModel
    let featureViewModels: FeatureViewModels

    @State private var selectedTab: NotchTab = .home
    @State private var slideDirection: Edge = .trailing

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
                ExpandedMediaView(viewModel: featureViewModels.media)
            case .shelf:
                FileShelfView(viewModel: featureViewModels.shelf)
            case .clipboard:
                ClipboardHistoryView(viewModel: featureViewModels.clipboard)
            case .monitor:
                ExpandedMonitorView(viewModel: featureViewModels.monitor)
            case .calendar:
                ExpandedCalendarView(viewModel: featureViewModels.calendar)
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
