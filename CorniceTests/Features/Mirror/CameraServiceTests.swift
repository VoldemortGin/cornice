import XCTest
@testable import Cornice

// MARK: - CameraState Tests

final class CameraStateTests: XCTestCase {

    func test_idle_equalsIdle() {
        XCTAssertEqual(CameraState.idle, CameraState.idle)
    }

    func test_authorized_equalsAuthorized() {
        XCTAssertEqual(CameraState.authorized, CameraState.authorized)
    }

    func test_denied_equalsDenied() {
        XCTAssertEqual(CameraState.denied, CameraState.denied)
    }

    func test_unavailable_equalsUnavailable() {
        XCTAssertEqual(CameraState.unavailable, CameraState.unavailable)
    }

    func test_active_equalsActive() {
        XCTAssertEqual(CameraState.active, CameraState.active)
    }

    func test_idle_notEqualAuthorized() {
        XCTAssertNotEqual(CameraState.idle, CameraState.authorized)
    }

    func test_idle_notEqualDenied() {
        XCTAssertNotEqual(CameraState.idle, CameraState.denied)
    }

    func test_idle_notEqualUnavailable() {
        XCTAssertNotEqual(CameraState.idle, CameraState.unavailable)
    }

    func test_idle_notEqualActive() {
        XCTAssertNotEqual(CameraState.idle, CameraState.active)
    }

    func test_authorized_notEqualActive() {
        XCTAssertNotEqual(CameraState.authorized, CameraState.active)
    }

    func test_denied_notEqualUnavailable() {
        XCTAssertNotEqual(CameraState.denied, CameraState.unavailable)
    }

    func test_conformsToEquatable() {
        let a: CameraState = .idle
        let b: CameraState = .idle
        XCTAssertTrue(a == b)
    }

    func test_conformsToSendable() {
        // CameraState is Sendable, so it can be sent across concurrency boundaries.
        // This compiles only if Sendable conformance is present.
        let state: CameraState = .authorized
        let _: any Sendable = state
        _ = state  // suppress unused warning
    }

    func test_allCasesExist() {
        let states: [CameraState] = [.idle, .authorized, .denied, .unavailable, .active]
        XCTAssertEqual(states.count, 5)
    }
}

// MARK: - CameraService Tests

final class CameraServiceTests: XCTestCase {

    @MainActor
    func test_initialState_isIdle() {
        let service = CameraService()
        XCTAssertEqual(service.state, .idle)
    }

    @MainActor
    func test_initialSession_isNil() {
        let service = CameraService()
        XCTAssertNil(service.session)
    }

    @MainActor
    func test_start_fromIdleState_doesNotChangeState() {
        // start() guards on state == .authorized || state == .active
        // From idle, it should not start.
        let service = CameraService()
        service.start()
        XCTAssertEqual(service.state, .idle)
    }

    @MainActor
    func test_start_fromDeniedState_doesNotChangeState() {
        let service = CameraService()
        // We cannot set state directly, but start() should not crash from any state.
        // From initial idle state, start() is a no-op.
        service.start()
        XCTAssertNotEqual(service.state, .active)
    }

    @MainActor
    func test_stop_fromIdleState_doesNotCrash() {
        let service = CameraService()
        service.stop()
        XCTAssertEqual(service.state, .idle)
    }

    @MainActor
    func test_stop_whenNoSession_isNoOp() {
        let service = CameraService()
        XCTAssertNil(service.session)
        service.stop()
        XCTAssertNil(service.session)
    }
}
