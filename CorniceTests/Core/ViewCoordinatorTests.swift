import XCTest
@testable import Cornice

/// Tests for ViewCoordinator -- the global singleton that coordinates notch panels
/// across screens, manages per-screen ViewModels, routes events, and tracks HUD state.
@MainActor
final class ViewCoordinatorTests: XCTestCase {

    // MARK: - Fresh Instance Helper

    private func makeFreshCoordinator() -> ViewCoordinator {
        ViewCoordinator()
    }

    // MARK: - Singleton Access

    func test_shared_returnsSameInstance() {
        let a = ViewCoordinator.shared
        let b = ViewCoordinator.shared
        XCTAssertTrue(a === b, "ViewCoordinator.shared must always return the same instance")
    }

    func test_shared_isNotNil() {
        XCTAssertNotNil(ViewCoordinator.shared)
    }

    // MARK: - Initial State

    func test_initialState_viewModelsIsEmpty_beforeSetup() {
        let coordinator = makeFreshCoordinator()
        XCTAssertTrue(coordinator.viewModels.isEmpty,
                      "Fresh coordinator should have no viewModels before setupForCurrentScreens")
    }

    func test_initialState_currentTabIsHome() {
        let coordinator = makeFreshCoordinator()
        XCTAssertEqual(coordinator.currentTab, "home",
                       "Default currentTab should be 'home'")
    }

    func test_initialState_hudEventIsNil() {
        let coordinator = makeFreshCoordinator()
        XCTAssertNil(coordinator.hudEvent,
                     "HUD event should be nil on a fresh coordinator")
    }

    // MARK: - Current Tab

    func test_currentTab_canBeChanged() {
        let coordinator = makeFreshCoordinator()
        coordinator.currentTab = "media"
        XCTAssertEqual(coordinator.currentTab, "media")
    }

    func test_currentTab_acceptsArbitraryStrings() {
        let coordinator = makeFreshCoordinator()
        coordinator.currentTab = "calendar"
        XCTAssertEqual(coordinator.currentTab, "calendar")
        coordinator.currentTab = "shelf"
        XCTAssertEqual(coordinator.currentTab, "shelf")
    }

    // MARK: - HUD State Management

    func test_showHUD_setsHudEvent() {
        let coordinator = makeFreshCoordinator()
        let event = SneakPeekEvent.volume(level: 0.75)
        coordinator.showHUD(event)
        XCTAssertEqual(coordinator.hudEvent, event,
                       "showHUD should set hudEvent to the provided event")
    }

    func test_showHUD_volumeEvent_setsCorrectValue() {
        let coordinator = makeFreshCoordinator()
        let event = SneakPeekEvent.volume(level: 0.5)
        coordinator.showHUD(event)
        XCTAssertEqual(coordinator.hudEvent, .volume(level: 0.5))
    }

    func test_showHUD_brightnessEvent_setsCorrectValue() {
        let coordinator = makeFreshCoordinator()
        let event = SneakPeekEvent.brightness(level: 0.3)
        coordinator.showHUD(event)
        XCTAssertEqual(coordinator.hudEvent, .brightness(level: 0.3))
    }

    func test_clearHUD_resetsHudEventToNil() {
        let coordinator = makeFreshCoordinator()
        coordinator.showHUD(.volume(level: 0.5))
        XCTAssertNotNil(coordinator.hudEvent)
        coordinator.clearHUD()
        XCTAssertNil(coordinator.hudEvent,
                     "clearHUD should reset hudEvent to nil")
    }

    func test_showHUD_replacesExistingEvent() {
        let coordinator = makeFreshCoordinator()
        coordinator.showHUD(.volume(level: 0.3))
        coordinator.showHUD(.brightness(level: 0.8))
        XCTAssertEqual(coordinator.hudEvent, .brightness(level: 0.8),
                       "A new showHUD call should replace the previous HUD event")
    }

    // MARK: - Active Screen Tracking

    func test_activeViewModel_returnsNil_whenNoActiveScreen() {
        let coordinator = makeFreshCoordinator()
        XCTAssertNil(coordinator.activeScreenUUID)
        XCTAssertNil(coordinator.activeViewModel,
                     "activeViewModel should be nil when activeScreenUUID is nil")
    }

    func test_viewModels_isDictionaryType() {
        let coordinator = makeFreshCoordinator()
        let dict: [String: NotchViewModel] = coordinator.viewModels
        XCTAssertNotNil(dict)
    }

    // MARK: - Setup for Current Screens

    func test_setupForCurrentScreens_populatesViewModels() {
        let coordinator = makeFreshCoordinator()
        coordinator.setupForCurrentScreens()
        let screenCount = NSScreen.screens.count
        XCTAssertEqual(coordinator.viewModels.count, screenCount,
                       "ViewModels count should match connected screens count")
    }

    func test_setupForCurrentScreens_calledTwice_preservesExistingViewModels() {
        let coordinator = makeFreshCoordinator()
        coordinator.setupForCurrentScreens()
        let firstPassModels = coordinator.viewModels

        coordinator.setupForCurrentScreens()
        let secondPassModels = coordinator.viewModels

        for (uuid, vm) in firstPassModels {
            if let secondVM = secondPassModels[uuid] {
                XCTAssertTrue(vm === secondVM,
                              "ViewModel for screen \(uuid) should be reused across setup calls")
            }
        }
    }

    func test_setupForCurrentScreens_viewModelKeysAreScreenUUIDs() {
        let coordinator = makeFreshCoordinator()
        coordinator.setupForCurrentScreens()
        for (uuid, vm) in coordinator.viewModels {
            XCTAssertEqual(vm.screenUUID, uuid,
                           "ViewModel's screenUUID should match the dictionary key")
        }
    }

    // MARK: - Sneak Peek Event Routing

    func test_routeSneakPeek_doesNotCrash_whenNoViewModels() {
        let coordinator = makeFreshCoordinator()
        let event = SneakPeekEvent.trackChange(title: "Test", artist: "Artist")
        coordinator.routeSneakPeek(event)
    }

    func test_routeSneakPeek_toAll_doesNotCrash() {
        let coordinator = makeFreshCoordinator()
        coordinator.setupForCurrentScreens()
        let event = SneakPeekEvent.volume(level: 0.6)
        coordinator.routeSneakPeek(event, toAll: true)
    }

    func test_routeSneakPeek_defaultToAllIsFalse() {
        let coordinator = makeFreshCoordinator()
        coordinator.setupForCurrentScreens()
        let event = SneakPeekEvent.brightness(level: 0.4)
        coordinator.routeSneakPeek(event)
    }

    // MARK: - ViewCoordinating Protocol Conformance

    func test_conformsToViewCoordinating() {
        let coordinator = makeFreshCoordinator()
        XCTAssertTrue(coordinator is ViewCoordinating,
                      "ViewCoordinator should conform to ViewCoordinating protocol")
    }

    // MARK: - SneakPeekEvent Equality (used by coordinator routing)

    func test_sneakPeekEvent_volume_equality() {
        let a = SneakPeekEvent.volume(level: 0.5)
        let b = SneakPeekEvent.volume(level: 0.5)
        let c = SneakPeekEvent.volume(level: 0.7)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_sneakPeekEvent_brightness_equality() {
        let a = SneakPeekEvent.brightness(level: 0.3)
        let b = SneakPeekEvent.brightness(level: 0.3)
        XCTAssertEqual(a, b)
    }

    func test_sneakPeekEvent_trackChange_equality() {
        let a = SneakPeekEvent.trackChange(title: "Song", artist: "Artist")
        let b = SneakPeekEvent.trackChange(title: "Song", artist: "Artist")
        let c = SneakPeekEvent.trackChange(title: "Other", artist: "Artist")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_sneakPeekEvent_differentCases_notEqual() {
        let volume = SneakPeekEvent.volume(level: 0.5)
        let brightness = SneakPeekEvent.brightness(level: 0.5)
        XCTAssertNotEqual(volume, brightness)
    }
}
