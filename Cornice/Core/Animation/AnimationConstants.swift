import SwiftUI

/// Centralized animation configurations for notch transitions.
/// All values are per PRD-01 Section 5.
enum AnimationConstants {

    // MARK: - Spring Animations

    /// Spring for Closed -> Open, SneakPeek -> Open transitions.
    /// Response 0.42s, slight overshoot (0.8 damping), feels responsive.
    static let openSpring = Animation.spring(
        response: 0.42,
        dampingFraction: 0.8,
        blendDuration: 0
    )

    /// Alias for backward compatibility with feature views.
    static let expandSpring = openSpring

    /// Spring for Open -> Closed, ExpandedDetail -> Closed transitions.
    /// Response 0.45s, critically damped (1.0), no overshoot, clean closure.
    static let closeSpring = Animation.spring(
        response: 0.45,
        dampingFraction: 1.0,
        blendDuration: 0
    )

    /// Spring for gesture-driven transitions (swipe release).
    /// Faster response (0.38s) to minimize perceived lag during interaction.
    static let interactiveSpring = Animation.interactiveSpring(
        response: 0.38,
        dampingFraction: 0.8,
        blendDuration: 0
    )

    // MARK: - Content Transitions

    /// Content appears by scaling from 0.8 at the top anchor while fading in.
    static let contentAppearTransition: AnyTransition = .scale(scale: 0.8, anchor: .top)
        .combined(with: .opacity)

    /// Tab switching: new tab slides in from trailing edge.
    static let tabInsertionTransition: AnyTransition = .move(edge: .trailing)
        .combined(with: .opacity)

    /// Tab switching: old tab slides out to leading edge.
    static let tabRemovalTransition: AnyTransition = .move(edge: .leading)
        .combined(with: .opacity)

    /// Asymmetric transition for tab content switching.
    static let tabSwitchTransition: AnyTransition = .asymmetric(
        insertion: tabInsertionTransition,
        removal: tabRemovalTransition
    )

    // MARK: - Timing Constants

    /// Default hover activation delay before opening the notch.
    static let defaultHoverDelay: TimeInterval = 0.2 // 200ms

    /// Default delay before collapsing after mouse leaves expanded area.
    static let defaultCollapseDelay: TimeInterval = 0.5 // 500ms

    /// Default sneak peek auto-dismiss duration.
    static let defaultSneakPeekDuration: TimeInterval = 3.0 // 3 seconds

    /// Default HUD display duration.
    static let defaultHUDDuration: TimeInterval = 2.0 // 2 seconds

    /// Minimum hover delay.
    static let minHoverDelay: TimeInterval = 0.05 // 50ms

    /// Maximum hover delay.
    static let maxHoverDelay: TimeInterval = 1.0 // 1000ms

    /// Minimum collapse delay.
    static let minCollapseDelay: TimeInterval = 0.2 // 200ms

    /// Maximum collapse delay.
    static let maxCollapseDelay: TimeInterval = 2.0 // 2000ms

    /// Minimum sneak peek duration.
    static let minSneakPeekDuration: TimeInterval = 1.0

    /// Maximum sneak peek duration.
    static let maxSneakPeekDuration: TimeInterval = 10.0

    // MARK: - Gesture Thresholds

    /// Minimum vertical distance (in points) to commit a swipe-to-open gesture.
    static let swipeCommitThreshold: CGFloat = 20.0

    /// Full expansion distance for gesture-driven opening.
    static let fullExpansionDistance: CGFloat = 80.0

    /// Expanded area margin for collapse detection (pts on each side).
    static let expandedAreaMargin: CGFloat = 20.0

    /// Hover tolerance around the notch activation rect (pts on each side).
    static let hoverTolerance: CGFloat = 4.0

    /// Drag proximity rect expansion for shelf auto-open (pts on each side).
    static let dragProximity: CGFloat = 60.0

    // MARK: - Corner Radii by State

    enum CornerRadii {
        static let closedTop: CGFloat = 10
        static let closedBottom: CGFloat = 14

        static let sneakPeekTop: CGFloat = 14
        static let sneakPeekBottom: CGFloat = 18

        static let openTop: CGFloat = 18
        static let openBottom: CGFloat = 24

        static let expandedDetailTop: CGFloat = 18
        static let expandedDetailBottom: CGFloat = 28
    }

    // MARK: - Default Sizes

    enum Sizes {
        /// Default open size.
        static let openWidth: CGFloat = 640
        static let openHeight: CGFloat = 190

        /// Default sneak peek size.
        static let sneakPeekWidth: CGFloat = 400
        static let sneakPeekHeight: CGFloat = 56

        /// Default expanded detail size.
        static let expandedDetailWidth: CGFloat = 700
        static let expandedDetailHeight: CGFloat = 380

        /// Virtual notch defaults (non-notch screens).
        static let virtualNotchWidth: CGFloat = 230
        static let virtualNotchHeight: CGFloat = 32
    }
}
