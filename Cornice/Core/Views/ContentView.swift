import SwiftUI

/// The master view displayed inside the notch panel.
/// Routes to the appropriate sub-view based on the current NotchState.
struct ContentView: View {
    @State var viewModel: NotchViewModel
    var featureViewModels: FeatureViewModels

    var body: some View {
        ZStack {
            // Background notch shape
            NotchShape(
                topCornerRadius: viewModel.topCornerRadius,
                bottomCornerRadius: viewModel.bottomCornerRadius
            )
            .fill(Color.black)

            // Content based on state
            contentForState
                .clipShape(
                    NotchShape(
                        topCornerRadius: viewModel.topCornerRadius,
                        bottomCornerRadius: viewModel.bottomCornerRadius
                    )
                )
        }
        .frame(width: viewModel.notchSize.width, height: viewModel.notchSize.height)
        .animation(AnimationConstants.openSpring, value: viewModel.state)
    }

    @ViewBuilder
    private var contentForState: some View {
        switch viewModel.state {
        case .closed:
            ClosedStateView(viewModel: viewModel, featureViewModels: featureViewModels)
                .transition(AnimationConstants.contentAppearTransition)

        case .sneakPeek(let event):
            SneakPeekView(event: event)
                .transition(AnimationConstants.contentAppearTransition)

        case .open:
            OpenStateView(viewModel: viewModel, featureViewModels: featureViewModels)
                .transition(AnimationConstants.contentAppearTransition)

        case .expandedDetail:
            ExpandedDetailView(viewModel: viewModel, featureViewModels: featureViewModels)
                .transition(AnimationConstants.contentAppearTransition)
        }
    }
}
