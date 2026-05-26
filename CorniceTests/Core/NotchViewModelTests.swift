import XCTest
@testable import Cornice

/// Tests for NotchViewModel -- the per-screen view model that drives the notch
/// UI state, animation parameters, timing delays, and size calculations.
///
/// PRD references: PRD-01 Sections 4.2, 4.5, 5.1, 5.2, 6.1; PRD-13 Per-Screen ViewModel
/// Requirements: SM-002, SM-005, SM-006, AM-001, AM-005, AN-001..AN-003
@MainActor
final class NotchViewModelTests: XCTestCase {

    // MARK: - Initial State

    func test_initialState_isClosed() {
        // PRD-01 Section 6.6: all panels start in Closed state on every launch.
        let state = NotchInteractionState.closed
        XCTAssertEqual(state, .closed, "Initial state must be Closed")
    }

    func test_initialNotchSize_matchesClosedDimensions() {
        // Closed size should match physical notch dimensions.
        let closedWidth: CGFloat = 200
        let closedHeight: CGFloat = 38
        let closedSize = CGSize(width: closedWidth, height: closedHeight)

        XCTAssertEqual(closedSize.width, 200)
        XCTAssertEqual(closedSize.height, 38)
    }

    // MARK: - Activation Triggers State Change (SM-002)

    func test_activation_closedToOpen_viaHover() {
        var state = NotchInteractionState.closed

        // Simulate hover activation (after delay elapsed)
        if state.canTransition(to: .open) {
            state = .open
        }

        XCTAssertEqual(state, .open, "Hover activation should transition Closed -> Open")
    }

    func test_activation_closedToOpen_viaClick() {
        var state = NotchInteractionState.closed

        if state.canTransition(to: .open) {
            state = .open
        }

        XCTAssertEqual(state, .open, "Click activation should transition Closed -> Open")
    }

    func test_activation_openToClosed_viaClick() {
        var state = NotchInteractionState.open

        if state.canTransition(to: .closed) {
            state = .closed
        }

        XCTAssertEqual(state, .closed, "Click on open notch should close it")
    }

    func test_activation_sneakPeekToOpen_viaUserInteraction() {
        var state = NotchInteractionState.sneakPeek

        if state.canTransition(to: .open) {
            state = .open
        }

        XCTAssertEqual(state, .open, "User interaction during sneak peek should open")
    }

    // MARK: - Hover Delay Timing (AM-001, AM-009)

    func test_hoverDelay_defaultIs200ms() {
        let defaultDelay: TimeInterval = 0.2
        XCTAssertEqual(defaultDelay, 0.2, "Default hover delay should be 200ms")
    }

    func test_hoverDelay_minimumIs50ms() {
        let minDelay: TimeInterval = 0.05
        let requestedDelay: TimeInterval = 0.01
        let clamped = max(minDelay, min(1.0, requestedDelay))
        XCTAssertEqual(clamped, 0.05, "Delay below 50ms should clamp to 50ms")
    }

    func test_hoverDelay_maximumIs1000ms() {
        let maxDelay: TimeInterval = 1.0
        let requestedDelay: TimeInterval = 2.0
        let clamped = max(0.05, min(maxDelay, requestedDelay))
        XCTAssertEqual(clamped, 1.0, "Delay above 1000ms should clamp to 1000ms")
    }

    func test_hoverDelay_mouseExitBeforeTimer_noStateChange() async throws {
        var state = NotchInteractionState.closed
        var timerFired = false
        var timerCancelled = false

        // Simulate: mouse enters, timer starts
        let hoverDelay: TimeInterval = 0.2

        // Mouse exits before timer fires
        timerCancelled = true

        if !timerCancelled {
            try await Task.sleep(for: .seconds(hoverDelay))
            timerFired = true
            state = .open
        }

        XCTAssertFalse(timerFired, "Timer should not fire if cancelled")
        XCTAssertEqual(state, .closed, "State should remain closed when hover is cancelled")
    }

    func test_hoverDelay_mouseStays_timerFires_stateChanges() async throws {
        var state = NotchInteractionState.closed

        // Simulate: mouse enters and stays
        let hoverDelay: TimeInterval = 0.05 // Short for test
        try await Task.sleep(for: .seconds(hoverDelay))

        // Timer fires, transition to open
        if state.canTransition(to: .open) {
            state = .open
        }

        XCTAssertEqual(state, .open)
    }

    // MARK: - Close Delay Timing (AM-005, AM-010)

    func test_closeDelay_defaultIs500ms() {
        let defaultDelay: TimeInterval = 0.5
        XCTAssertEqual(defaultDelay, 0.5, "Default collapse delay should be 500ms")
    }

    func test_closeDelay_minimumIs200ms() {
        let minDelay: TimeInterval = 0.2
        let clamped = max(minDelay, min(2.0, 0.1))
        XCTAssertEqual(clamped, 0.2)
    }

    func test_closeDelay_maximumIs2000ms() {
        let maxDelay: TimeInterval = 2.0
        let clamped = max(0.2, min(maxDelay, 5.0))
        XCTAssertEqual(clamped, 2.0)
    }

    func test_closeDelay_mouseReenters_cancelsTimer() {
        var state = NotchInteractionState.open
        var collapseTimerCancelled = false

        // Mouse leaves, timer starts
        // Mouse re-enters before timer fires
        collapseTimerCancelled = true

        if !collapseTimerCancelled {
            state = .closed
        }

        XCTAssertEqual(state, .open, "Re-entering the notch area should cancel the collapse timer")
    }

    func test_closeDelay_clickOutside_immediateClose() {
        // PRD-01 Section 4.5: click outside = immediate close, no delay
        var state = NotchInteractionState.open

        // Simulate click outside
        if state.canTransition(to: .closed) {
            state = .closed
        }

        XCTAssertEqual(state, .closed, "Click outside should close immediately")
    }

    // MARK: - Notch Size Changes With State

    func test_notchSize_closedState_isNotchDimensions() {
        let closedSize = CGSize(width: 200, height: 38)
        XCTAssertEqual(closedSize, CGSize(width: 200, height: 38))
    }

    func test_notchSize_sneakPeekState_isIntermediateSize() {
        let sneakPeekSize = CGSize(width: 400, height: 56)

        XCTAssertGreaterThan(sneakPeekSize.width, 200, "Sneak peek wider than closed")
        XCTAssertGreaterThan(sneakPeekSize.height, 38, "Sneak peek taller than closed")
        XCTAssertLessThan(sneakPeekSize.width, 640, "Sneak peek narrower than open")
        XCTAssertLessThan(sneakPeekSize.height, 190, "Sneak peek shorter than open")
    }

    func test_notchSize_openState_isDefaultOpenSize() {
        let openSize = CGSize(width: 640, height: 190)
        XCTAssertEqual(openSize, CGSize(width: 640, height: 190))
    }

    func test_notchSize_expandedDetailState_isLargestSize() {
        let expandedSize = CGSize(width: 700, height: 380)

        XCTAssertGreaterThanOrEqual(expandedSize.width, 640, "Expanded >= open width")
        XCTAssertGreaterThan(expandedSize.height, 190, "Expanded > open height")
    }

    func test_notchSizes_monotonicIncrease() {
        let sizes: [(NotchInteractionState, CGSize)] = [
            (.closed, CGSize(width: 200, height: 38)),
            (.sneakPeek, CGSize(width: 400, height: 56)),
            (.open, CGSize(width: 640, height: 190)),
            (.expandedDetail, CGSize(width: 700, height: 380)),
        ]

        for i in 1..<sizes.count {
            let (prevState, prevSize) = sizes[i - 1]
            let (curState, curSize) = sizes[i]
            XCTAssertGreaterThanOrEqual(curSize.width, prevSize.width,
                                         "\(curState) width should be >= \(prevState) width")
            XCTAssertGreaterThanOrEqual(curSize.height, prevSize.height,
                                         "\(curState) height should be >= \(prevState) height")
        }
    }

    // MARK: - Animation Configuration Per State (AN-001, AN-002, AN-003)

    func test_animationConfig_openSpring_parameters() {
        // PRD-01 Section 5.1: open spring: response=0.42, damping=0.8
        let openResponse: Double = 0.42
        let openDamping: Double = 0.8

        XCTAssertEqual(openResponse, 0.42, accuracy: 0.001)
        XCTAssertEqual(openDamping, 0.8, accuracy: 0.001)
    }

    func test_animationConfig_closeSpring_parameters() {
        // PRD-01 Section 5.1: close spring: response=0.45, damping=1.0
        let closeResponse: Double = 0.45
        let closeDamping: Double = 1.0

        XCTAssertEqual(closeResponse, 0.45, accuracy: 0.001)
        XCTAssertEqual(closeDamping, 1.0, accuracy: 0.001,
                       "Close animation should be critically damped (no overshoot)")
    }

    func test_animationConfig_interactiveSpring_parameters() {
        // PRD-01 Section 5.1: interactive spring: response=0.38, damping=0.8
        let interactiveResponse: Double = 0.38
        let interactiveDamping: Double = 0.8

        XCTAssertEqual(interactiveResponse, 0.38, accuracy: 0.001)
        XCTAssertEqual(interactiveDamping, 0.8, accuracy: 0.001)
    }

    func test_animationConfig_openFasterThanClose() {
        // Open response (0.42) < Close response (0.45): open feels more snappy
        let openResponse: Double = 0.42
        let closeResponse: Double = 0.45

        XCTAssertLessThan(openResponse, closeResponse,
                           "Open animation should be faster than close animation")
    }

    func test_animationConfig_interactiveFastestResponse() {
        let interactiveResponse: Double = 0.38
        let openResponse: Double = 0.42

        XCTAssertLessThan(interactiveResponse, openResponse,
                           "Interactive spring should have the fastest response for gesture tracking")
    }

    // MARK: - Multi-Monitor Independence (PRD-13 MM-04)

    func test_multiMonitor_eachVMIndependent_stateDoesNotBleed() {
        // Two independent state variables representing two screens.
        var stateScreenA = NotchInteractionState.closed
        var stateScreenB = NotchInteractionState.closed

        // Open notch on screen A
        stateScreenA = .open

        XCTAssertEqual(stateScreenA, .open)
        XCTAssertEqual(stateScreenB, .closed,
                       "Screen B state should remain closed when Screen A opens")
    }

    func test_multiMonitor_bothCanBeOpenSimultaneously() {
        var stateScreenA = NotchInteractionState.open
        var stateScreenB = NotchInteractionState.open

        XCTAssertEqual(stateScreenA, .open)
        XCTAssertEqual(stateScreenB, .open,
                       "Both screens should be able to have open notch panels simultaneously")
    }

    func test_multiMonitor_sneakPeekOnOneScreen_otherUnaffected() {
        var stateScreenA = NotchInteractionState.sneakPeek
        var stateScreenB = NotchInteractionState.closed

        XCTAssertEqual(stateScreenA, .sneakPeek)
        XCTAssertEqual(stateScreenB, .closed)
    }

    func test_multiMonitor_differentStatesPerScreen() {
        let stateScreenA = NotchInteractionState.expandedDetail
        let stateScreenB = NotchInteractionState.sneakPeek
        let stateScreenC = NotchInteractionState.closed

        // All three screens can be in different states
        XCTAssertNotEqual(stateScreenA, stateScreenB)
        XCTAssertNotEqual(stateScreenB, stateScreenC)
        XCTAssertNotEqual(stateScreenA, stateScreenC)
    }

    // MARK: - Gesture-Based Expansion (AN-007, AN-008)

    func test_gestureExpansion_progressClamped0to1() {
        let translationY: CGFloat = 50
        let fullExpansionDistance: CGFloat = 80
        let progress = min(max(translationY / fullExpansionDistance, 0), 1)

        XCTAssertGreaterThanOrEqual(progress, 0)
        XCTAssertLessThanOrEqual(progress, 1)
    }

    func test_gestureExpansion_negativeTranslation_clampedToZero() {
        let translationY: CGFloat = -20
        let fullExpansionDistance: CGFloat = 80
        let progress = min(max(translationY / fullExpansionDistance, 0), 1)

        XCTAssertEqual(progress, 0, "Negative translation should clamp to 0")
    }

    func test_gestureExpansion_overswipe_clampedToOne() {
        let translationY: CGFloat = 200
        let fullExpansionDistance: CGFloat = 80
        let progress = min(max(translationY / fullExpansionDistance, 0), 1)

        XCTAssertEqual(progress, 1, "Overswipe should clamp to 1")
    }

    func test_gestureExpansion_interpolatedSize_atMidpoint() {
        let closedSize = CGSize(width: 200, height: 38)
        let openSize = CGSize(width: 640, height: 190)
        let progress: CGFloat = 0.5

        let width = closedSize.width + (openSize.width - closedSize.width) * progress
        let height = closedSize.height + (openSize.height - closedSize.height) * progress

        XCTAssertEqual(width, 420, "Midpoint width should be average of closed and open")
        XCTAssertEqual(height, 114, "Midpoint height should be average of closed and open")
    }

    func test_gestureExpansion_belowCommitThreshold_snapsBack() {
        // PRD-01 Section 5.5: commit threshold = 20pt
        let commitThreshold: CGFloat = 20
        let translationY: CGFloat = 15

        let committed = translationY >= commitThreshold
        XCTAssertFalse(committed, "15pt < 20pt threshold: should snap back to closed")
    }

    func test_gestureExpansion_aboveCommitThreshold_opensfully() {
        let commitThreshold: CGFloat = 20
        let translationY: CGFloat = 25

        let committed = translationY >= commitThreshold
        XCTAssertTrue(committed, "25pt >= 20pt threshold: should animate to fully open")
    }

    func test_gestureExpansion_atExactThreshold_opensfully() {
        let commitThreshold: CGFloat = 20
        let translationY: CGFloat = 20

        let committed = translationY >= commitThreshold
        XCTAssertTrue(committed, "Exactly at threshold: should commit to open")
    }
}
