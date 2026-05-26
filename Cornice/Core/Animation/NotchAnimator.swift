import SwiftUI

/// Coordinates animations between notch states.
/// Provides high-level animation orchestration for state transitions,
/// handling interruption of in-progress animations.
@MainActor
final class NotchAnimator {

    /// The animation to use for a given state transition.
    static func animation(from: NotchState, to: NotchState) -> Animation {
        switch to {
        case .closed:
            return AnimationConstants.closeSpring
        case .sneakPeek, .open, .expandedDetail:
            return AnimationConstants.openSpring
        }
    }

    /// Animates a NotchViewModel to the target state.
    static func animate(
        viewModel: NotchViewModel,
        to state: NotchState,
        completion: (() -> Void)? = nil
    ) {
        viewModel.transition(to: state)
        // Completion callback (if needed in future for chained animations).
        completion?()
    }

    /// Performs a gesture-driven interactive animation to completion.
    static func completeGesture(
        viewModel: NotchViewModel,
        translation: CGFloat
    ) {
        viewModel.endGesture(translation: translation)
    }
}
