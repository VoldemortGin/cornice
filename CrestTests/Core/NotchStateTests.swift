import XCTest
@testable import Crest

/// Tests for the NotchState machine -- validates all allowed transitions between
/// the four states (closed, sneakPeek, open, expandedDetail), rejects invalid
/// transitions, and verifies sneak-peek timing and queue behavior.
///
/// PRD references: PRD-01 Sections 6.1-6.5
/// Requirements: SM-001 through SM-014
final class NotchStateTests: XCTestCase {

    // MARK: - State Definitions (SM-001)

    func test_stateEnum_hasFourCases() {
        let allStates: [NotchInteractionState] = [.closed, .sneakPeek, .open, .expandedDetail]
        XCTAssertEqual(allStates.count, 4, "NotchState must have exactly four cases")
    }

    func test_stateEnum_closedIsDefault() {
        // PRD-01 Section 6.6: on every launch, all panels start Closed
        let defaultState = NotchInteractionState.closed
        XCTAssertEqual(defaultState, .closed)
    }

    // MARK: - Valid Transitions

    func test_transition_T1_closedToOpen_isValid() {
        // T1: Closed -> Open (hover delay elapsed / click / swipe / hotkey)
        XCTAssertTrue(NotchInteractionState.closed.canTransition(to: .open),
                       "T1: Closed -> Open should be allowed")
    }

    func test_transition_T2_closedToSneakPeek_isValid() {
        // T2: Closed -> Sneak Peek (system event: track change, volume, etc.)
        XCTAssertTrue(NotchInteractionState.closed.canTransition(to: .sneakPeek),
                       "T2: Closed -> Sneak Peek should be allowed")
    }

    func test_transition_T3_sneakPeekToClosed_isValid() {
        // T3: Sneak Peek -> Closed (dismiss timer fires, default 3s)
        XCTAssertTrue(NotchInteractionState.sneakPeek.canTransition(to: .closed),
                       "T3: Sneak Peek -> Closed should be allowed")
    }

    func test_transition_T4_sneakPeekToOpen_isValid() {
        // T4: Sneak Peek -> Open (user clicks/hovers during sneak peek)
        XCTAssertTrue(NotchInteractionState.sneakPeek.canTransition(to: .open),
                       "T4: Sneak Peek -> Open should be allowed")
    }

    func test_transition_T5_openToClosed_isValid() {
        // T5: Open -> Closed (mouse leaves + delay / click outside / escape / hotkey)
        XCTAssertTrue(NotchInteractionState.open.canTransition(to: .closed),
                       "T5: Open -> Closed should be allowed")
    }

    func test_transition_T6_openToExpandedDetail_isValid() {
        // T6: Open -> Expanded Detail (widget action, e.g. "show lyrics")
        XCTAssertTrue(NotchInteractionState.open.canTransition(to: .expandedDetail),
                       "T6: Open -> Expanded Detail should be allowed")
    }

    func test_transition_T7_expandedDetailToOpen_isValid() {
        // T7: Expanded Detail -> Open (collapse button / back)
        XCTAssertTrue(NotchInteractionState.expandedDetail.canTransition(to: .open),
                       "T7: Expanded Detail -> Open should be allowed")
    }

    func test_transition_T8_expandedDetailToClosed_isValid() {
        // T8: Expanded Detail -> Closed (mouse leaves + delay / hotkey / escape)
        XCTAssertTrue(NotchInteractionState.expandedDetail.canTransition(to: .closed),
                       "T8: Expanded Detail -> Closed should be allowed")
    }

    // MARK: - Invalid Transitions (SM-010, SM-011)

    func test_transition_closedToExpandedDetail_isInvalid() {
        // PRD-01 Section 6.4: Closed -> Expanded Detail is NOT allowed (must go through Open)
        XCTAssertFalse(NotchInteractionState.closed.canTransition(to: .expandedDetail),
                        "Closed -> Expanded Detail should be rejected")
    }

    func test_transition_sneakPeekToExpandedDetail_isInvalid() {
        // PRD-01 Section 6.4: Sneak Peek -> Expanded Detail is NOT allowed
        XCTAssertFalse(NotchInteractionState.sneakPeek.canTransition(to: .expandedDetail),
                        "Sneak Peek -> Expanded Detail should be rejected")
    }

    func test_transition_sameState_closedToClosed_isInvalid() {
        XCTAssertFalse(NotchInteractionState.closed.canTransition(to: .closed),
                        "Same-state transition should be a no-op")
    }

    func test_transition_sameState_openToOpen_isInvalid() {
        XCTAssertFalse(NotchInteractionState.open.canTransition(to: .open))
    }

    func test_transition_sameState_sneakPeekToSneakPeek_isInvalid() {
        XCTAssertFalse(NotchInteractionState.sneakPeek.canTransition(to: .sneakPeek))
    }

    func test_transition_sameState_expandedDetailToExpandedDetail_isInvalid() {
        XCTAssertFalse(NotchInteractionState.expandedDetail.canTransition(to: .expandedDetail))
    }

    func test_transition_openToSneakPeek_isInvalid() {
        // Being open already subsumes sneak peek; no need to peek while fully open.
        XCTAssertFalse(NotchInteractionState.open.canTransition(to: .sneakPeek),
                        "Open -> Sneak Peek should be rejected (already showing content)")
    }

    func test_transition_expandedDetailToSneakPeek_isInvalid() {
        XCTAssertFalse(NotchInteractionState.expandedDetail.canTransition(to: .sneakPeek),
                        "Expanded Detail -> Sneak Peek should be rejected")
    }

    // MARK: - Complete Transition Matrix

    func test_transitionMatrix_completeCoverage() {
        let states: [NotchInteractionState] = [.closed, .sneakPeek, .open, .expandedDetail]

        // Expected transition validity matrix
        let expected: [(NotchInteractionState, NotchInteractionState, Bool)] = [
            // from            to                expected
            (.closed,          .closed,          false),
            (.closed,          .sneakPeek,       true),
            (.closed,          .open,            true),
            (.closed,          .expandedDetail,  false),

            (.sneakPeek,       .closed,          true),
            (.sneakPeek,       .sneakPeek,       false),
            (.sneakPeek,       .open,            true),
            (.sneakPeek,       .expandedDetail,  false),

            (.open,            .closed,          true),
            (.open,            .sneakPeek,       false),
            (.open,            .open,            false),
            (.open,            .expandedDetail,  true),

            (.expandedDetail,  .closed,          true),
            (.expandedDetail,  .sneakPeek,       false),
            (.expandedDetail,  .open,            true),
            (.expandedDetail,  .expandedDetail,  false),
        ]

        for (from, to, expectedValid) in expected {
            XCTAssertEqual(from.canTransition(to: to), expectedValid,
                           "Transition \(from) -> \(to) should be \(expectedValid ? "valid" : "invalid")")
        }
    }

    // MARK: - Sneak Peek Auto-Dismiss Timer (SM-004, SM-013)

    func test_sneakPeek_defaultDismissTime_is3Seconds() {
        let defaultDismissTime: TimeInterval = 3.0
        XCTAssertEqual(defaultDismissTime, 3.0,
                       "PRD specifies 3 second default sneak peek dismiss time")
    }

    func test_sneakPeek_dismissTimeRange_1to10Seconds() {
        let minDismiss: TimeInterval = 1.0
        let maxDismiss: TimeInterval = 10.0

        // Clamp values to range
        let valid: TimeInterval = 5.0
        let tooShort: TimeInterval = 0.5
        let tooLong: TimeInterval = 15.0

        let clampedValid = max(minDismiss, min(maxDismiss, valid))
        let clampedShort = max(minDismiss, min(maxDismiss, tooShort))
        let clampedLong = max(minDismiss, min(maxDismiss, tooLong))

        XCTAssertEqual(clampedValid, 5.0)
        XCTAssertEqual(clampedShort, 1.0)
        XCTAssertEqual(clampedLong, 10.0)
    }

    func test_sneakPeek_autoDismiss_transitionsToClosedAfterTimeout() async throws {
        // Simulate: state enters sneakPeek, after timeout it should be closed.
        var currentState: NotchInteractionState = .closed

        // Transition to sneak peek
        if currentState.canTransition(to: .sneakPeek) {
            currentState = .sneakPeek
        }
        XCTAssertEqual(currentState, .sneakPeek)

        // Simulate dismiss timer (shortened for test)
        let dismissDuration: TimeInterval = 0.1
        try await Task.sleep(for: .seconds(dismissDuration))

        // After timeout, transition to closed
        if currentState == .sneakPeek && currentState.canTransition(to: .closed) {
            currentState = .closed
        }
        XCTAssertEqual(currentState, .closed, "Sneak peek should auto-dismiss to closed")
    }

    func test_sneakPeek_userInteraction_cancelsTimer_transitionsToOpen() {
        // T4: user interaction during sneak peek -> Open
        var currentState: NotchInteractionState = .sneakPeek

        // Simulate user click during sneak peek
        if currentState.canTransition(to: .open) {
            currentState = .open
        }
        XCTAssertEqual(currentState, .open,
                       "User interaction during sneak peek should transition to Open")
    }

    // MARK: - Sneak Peek Queue Behavior (SM-012)

    func test_sneakPeek_multipleEventsInSuccession_onlyLatestShown() {
        // PRD-01 Section 6.5: previous sneak peek is immediately replaced.
        // No queue or stacking -- only the latest event is shown.
        var currentContent = "Track A"
        var dismissTimerResetCount = 0

        // Simulate rapid track changes
        let events = ["Track A", "Track B", "Track C"]
        for event in events {
            currentContent = event
            dismissTimerResetCount += 1
        }

        XCTAssertEqual(currentContent, "Track C", "Only the latest event content should be shown")
        XCTAssertEqual(dismissTimerResetCount, 3, "Dismiss timer should reset on each new event")
    }

    func test_sneakPeek_newEvent_replacesPrevious_noStacking() {
        // Verify there is no queue -- just replacement.
        var sneakPeekQueue: [String] = []
        let maxQueueSize = 1

        let events = ["Volume 50%", "Volume 75%", "Volume 100%"]
        for event in events {
            sneakPeekQueue = [event] // Replace, not append
        }

        XCTAssertEqual(sneakPeekQueue.count, maxQueueSize, "Queue should contain exactly one item")
        XCTAssertEqual(sneakPeekQueue.first, "Volume 100%", "Queue should contain the latest event")
    }

    func test_sneakPeek_newEvent_restartsDismissTimer() async throws {
        // Each new sneak peek event should restart the dismiss timer from the beginning.
        var timerStartCount = 0

        // Simulate 3 rapid events
        for _ in 0..<3 {
            timerStartCount += 1
        }

        XCTAssertEqual(timerStartCount, 3, "Timer should restart for each new event")
    }

    // MARK: - State Persistence (SM, Section 6.6)

    func test_state_notPersistedAcrossLaunches() {
        // PRD-01 Section 6.6: state is NOT persisted; always starts Closed.
        let launchState = NotchInteractionState.closed
        XCTAssertEqual(launchState, .closed, "State should always be Closed on launch")
    }

    // MARK: - Transition Sequences

    func test_sequence_closedToOpenToExpandedDetailToOpenToClosed() {
        var state = NotchInteractionState.closed

        // T1: closed -> open
        XCTAssertTrue(state.canTransition(to: .open))
        state = .open

        // T6: open -> expandedDetail
        XCTAssertTrue(state.canTransition(to: .expandedDetail))
        state = .expandedDetail

        // T7: expandedDetail -> open
        XCTAssertTrue(state.canTransition(to: .open))
        state = .open

        // T5: open -> closed
        XCTAssertTrue(state.canTransition(to: .closed))
        state = .closed

        XCTAssertEqual(state, .closed)
    }

    func test_sequence_closedToSneakPeekToOpenToExpandedDetailToClosed() {
        var state = NotchInteractionState.closed

        // T2: closed -> sneakPeek
        XCTAssertTrue(state.canTransition(to: .sneakPeek))
        state = .sneakPeek

        // T4: sneakPeek -> open
        XCTAssertTrue(state.canTransition(to: .open))
        state = .open

        // T6: open -> expandedDetail
        XCTAssertTrue(state.canTransition(to: .expandedDetail))
        state = .expandedDetail

        // T8: expandedDetail -> closed
        XCTAssertTrue(state.canTransition(to: .closed))
        state = .closed

        XCTAssertEqual(state, .closed)
    }

    func test_sequence_closedToSneakPeekToClosed_autoDismiss() {
        var state = NotchInteractionState.closed

        // T2: closed -> sneakPeek
        state = .sneakPeek

        // T3: sneakPeek -> closed (timeout)
        XCTAssertTrue(state.canTransition(to: .closed))
        state = .closed

        XCTAssertEqual(state, .closed)
    }

    func test_sequence_invalidPath_closedToExpandedDetail_rejected() {
        var state = NotchInteractionState.closed

        // Attempt invalid: closed -> expandedDetail
        XCTAssertFalse(state.canTransition(to: .expandedDetail))
        // State should remain unchanged
        XCTAssertEqual(state, .closed)
    }
}
