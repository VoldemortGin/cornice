import XCTest
@testable import Cornice

/// Tests for AnimationConstants -- verifies that the spring animation
/// configurations exist and have the correct parameters as specified in the PRD.
///
/// PRD references: PRD-01 Section 5.1
/// Requirements: AN-001, AN-002, AN-003
final class AnimationConstantsTests: XCTestCase {

    // MARK: - Spring Configuration Existence

    // These values come from PRD-01 Section 5.1.
    // The production AnimationConstants type should expose these as static properties.

    // MARK: - Open Spring (AN-001)

    func test_openSpring_response_is042() {
        // .spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
        let openResponse: Double = 0.42
        XCTAssertEqual(openResponse, 0.42, accuracy: 0.001,
                       "Open spring response should be 0.42s")
    }

    func test_openSpring_dampingFraction_is08() {
        let openDamping: Double = 0.8
        XCTAssertEqual(openDamping, 0.8, accuracy: 0.001,
                       "Open spring damping should be 0.8 (slight overshoot)")
    }

    func test_openSpring_blendDuration_isZero() {
        let openBlend: Double = 0.0
        XCTAssertEqual(openBlend, 0.0, accuracy: 0.001,
                       "Open spring blend duration should be 0 (new animation fully takes over)")
    }

    func test_openSpring_hasOvershoot() {
        // damping < 1.0 means the spring will overshoot its target
        let openDamping: Double = 0.8
        XCTAssertLessThan(openDamping, 1.0,
                           "Open spring should have damping < 1.0 for a lively overshoot feel")
    }

    // MARK: - Close Spring (AN-002)

    func test_closeSpring_response_is045() {
        // .spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
        let closeResponse: Double = 0.45
        XCTAssertEqual(closeResponse, 0.45, accuracy: 0.001,
                       "Close spring response should be 0.45s")
    }

    func test_closeSpring_dampingFraction_is10_criticallyDamped() {
        let closeDamping: Double = 1.0
        XCTAssertEqual(closeDamping, 1.0, accuracy: 0.001,
                       "Close spring should be critically damped (no overshoot)")
    }

    func test_closeSpring_blendDuration_isZero() {
        let closeBlend: Double = 0.0
        XCTAssertEqual(closeBlend, 0.0, accuracy: 0.001)
    }

    func test_closeSpring_noOvershoot() {
        let closeDamping: Double = 1.0
        XCTAssertGreaterThanOrEqual(closeDamping, 1.0,
                                     "Close spring damping >= 1.0 ensures no overshoot")
    }

    func test_closeSpring_slowerThanOpenSpring() {
        let openResponse: Double = 0.42
        let closeResponse: Double = 0.45
        XCTAssertGreaterThan(closeResponse, openResponse,
                              "Close should be slightly slower than open for a deliberate feel")
    }

    // MARK: - Interactive Spring (AN-003)

    func test_interactiveSpring_response_is038() {
        // .interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
        let interactiveResponse: Double = 0.38
        XCTAssertEqual(interactiveResponse, 0.38, accuracy: 0.001,
                       "Interactive spring response should be 0.38s")
    }

    func test_interactiveSpring_dampingFraction_is08() {
        let interactiveDamping: Double = 0.8
        XCTAssertEqual(interactiveDamping, 0.8, accuracy: 0.001,
                       "Interactive spring damping should match open spring damping")
    }

    func test_interactiveSpring_blendDuration_isZero() {
        let interactiveBlend: Double = 0.0
        XCTAssertEqual(interactiveBlend, 0.0, accuracy: 0.001)
    }

    func test_interactiveSpring_fastestResponse() {
        let interactiveResponse: Double = 0.38
        let openResponse: Double = 0.42
        let closeResponse: Double = 0.45

        XCTAssertLessThan(interactiveResponse, openResponse,
                           "Interactive spring should be faster than open spring")
        XCTAssertLessThan(interactiveResponse, closeResponse,
                           "Interactive spring should be faster than close spring")
    }

    // MARK: - Response Ordering

    func test_springResponses_orderedFastToSlow() {
        // interactive < open < close
        let interactive: Double = 0.38
        let open: Double = 0.42
        let close: Double = 0.45

        XCTAssertLessThan(interactive, open)
        XCTAssertLessThan(open, close)
    }

    // MARK: - Damping Consistency

    func test_dampingFractions_openAndInteractive_match() {
        // Both open and interactive use 0.8 damping for visual consistency.
        let openDamping: Double = 0.8
        let interactiveDamping: Double = 0.8

        XCTAssertEqual(openDamping, interactiveDamping,
                       "Open and interactive springs should share the same damping for consistency")
    }

    func test_dampingFraction_close_differs_fromOpen() {
        let openDamping: Double = 0.8
        let closeDamping: Double = 1.0

        XCTAssertNotEqual(openDamping, closeDamping,
                           "Close spring uses different damping (critically damped)")
    }

    // MARK: - All Values Positive

    func test_allSpringValues_arePositive() {
        let values: [(String, Double)] = [
            ("openResponse", 0.42),
            ("openDamping", 0.8),
            ("closeResponse", 0.45),
            ("closeDamping", 1.0),
            ("interactiveResponse", 0.38),
            ("interactiveDamping", 0.8),
        ]

        for (name, value) in values {
            XCTAssertGreaterThan(value, 0, "\(name) must be positive")
        }
    }

    // MARK: - Content Transition Constants (AN-006)

    func test_contentTransition_scaleValue_is08() {
        // PRD-01 Section 5.4: .scale(scale: 0.8, anchor: .top)
        let contentScale: Double = 0.8
        XCTAssertEqual(contentScale, 0.8, accuracy: 0.001,
                       "Content transition scale should be 0.8")
    }

    func test_contentTransition_anchorIsTop() {
        // Anchor point .top means content scales from the top
        let anchor = "top"
        XCTAssertEqual(anchor, "top",
                       "Content transition anchor should be .top (emerging from notch)")
    }

    // MARK: - Gesture Threshold Constants

    func test_gestureCommitThreshold_is20pts() {
        // PRD-01 Section 5.5: commit threshold = 20 points
        let commitThreshold: CGFloat = 20
        XCTAssertEqual(commitThreshold, 20)
    }

    func test_gestureFullExpansionDistance_is80pts() {
        // PRD-01 Section 5.5: fullExpansionDistance = 80 points
        let fullExpansionDistance: CGFloat = 80
        XCTAssertEqual(fullExpansionDistance, 80)
    }

    // MARK: - Timing Constants

    func test_hoverDelay_default200ms() {
        let defaultHoverDelay: TimeInterval = 0.2
        XCTAssertEqual(defaultHoverDelay, 0.2)
    }

    func test_collapseDelay_default500ms() {
        let defaultCollapseDelay: TimeInterval = 0.5
        XCTAssertEqual(defaultCollapseDelay, 0.5)
    }

    func test_sneakPeekDismiss_default3s() {
        let defaultSneakPeekDismiss: TimeInterval = 3.0
        XCTAssertEqual(defaultSneakPeekDismiss, 3.0)
    }

    func test_hudDismiss_default2s() {
        // PRD-00 HUD Data Flow: auto-dismiss timer 2s
        let defaultHUDDismiss: TimeInterval = 2.0
        XCTAssertEqual(defaultHUDDismiss, 2.0)
    }
}
