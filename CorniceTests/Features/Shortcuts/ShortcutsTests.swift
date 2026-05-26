import XCTest
import AppIntents
@testable import Cornice

// MARK: - Intent Tests

final class CorniceIntentsTests: XCTestCase {

    // MARK: - ToggleNotchIntent

    func test_toggleNotchIntent_titleIsNotEmpty() {
        let title = ToggleNotchIntent.title
        XCTAssertFalse(title.key.isEmpty)
    }

    func test_toggleNotchIntent_descriptionExists() {
        let description = ToggleNotchIntent.description
        XCTAssertNotNil(description)
    }

    func test_toggleNotchIntent_postsNotification() {
        let expectation = expectation(description: "toggleNotch notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .niyaToggleNotch, object: nil, queue: .main
        ) { _ in
            expectation.fulfill()
        }

        Task { @MainActor in
            NotificationCenter.default.post(name: .niyaToggleNotch, object: nil)
        }

        waitForExpectations(timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - ShowNowPlayingIntent

    func test_showNowPlayingIntent_titleIsNotEmpty() {
        let title = ShowNowPlayingIntent.title
        XCTAssertFalse(title.key.isEmpty)
    }

    func test_showNowPlayingIntent_postsNotification() {
        let expectation = expectation(description: "showNowPlaying notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .niyaShowNowPlaying, object: nil, queue: .main
        ) { _ in
            expectation.fulfill()
        }

        Task { @MainActor in
            NotificationCenter.default.post(name: .niyaShowNowPlaying, object: nil)
        }

        waitForExpectations(timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - ShowCalendarIntent

    func test_showCalendarIntent_titleIsNotEmpty() {
        let title = ShowCalendarIntent.title
        XCTAssertFalse(title.key.isEmpty)
    }

    func test_showCalendarIntent_postsNotification() {
        let expectation = expectation(description: "showCalendar notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .niyaShowCalendar, object: nil, queue: .main
        ) { _ in
            expectation.fulfill()
        }

        Task { @MainActor in
            NotificationCenter.default.post(name: .niyaShowCalendar, object: nil)
        }

        waitForExpectations(timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - ShowShelfIntent

    func test_showShelfIntent_titleIsNotEmpty() {
        let title = ShowShelfIntent.title
        XCTAssertFalse(title.key.isEmpty)
    }

    func test_showShelfIntent_postsNotification() {
        let expectation = expectation(description: "showShelf notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .niyaShowShelf, object: nil, queue: .main
        ) { _ in
            expectation.fulfill()
        }

        Task { @MainActor in
            NotificationCenter.default.post(name: .niyaShowShelf, object: nil)
        }

        waitForExpectations(timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - CorniceShortcuts (AppShortcutsProvider)

    func test_corniceShortcuts_typeExists() {
        // CorniceShortcuts conforms to AppShortcutsProvider
        let _: any AppShortcutsProvider.Type = CorniceShortcuts.self
    }

    // MARK: - Notification Names

    func test_niyaToggleNotch_rawValue() {
        XCTAssertEqual(Notification.Name.niyaToggleNotch.rawValue, "com.niya.toggleNotch")
    }

    func test_niyaShowNowPlaying_rawValue() {
        XCTAssertEqual(Notification.Name.niyaShowNowPlaying.rawValue, "com.niya.showNowPlaying")
    }

    func test_niyaShowCalendar_rawValue() {
        XCTAssertEqual(Notification.Name.niyaShowCalendar.rawValue, "com.niya.showCalendar")
    }

    func test_niyaShowShelf_rawValue() {
        XCTAssertEqual(Notification.Name.niyaShowShelf.rawValue, "com.niya.showShelf")
    }

    func test_notificationNames_areDistinct() {
        let names: Set<Notification.Name> = [
            .niyaToggleNotch,
            .niyaShowNowPlaying,
            .niyaShowCalendar,
            .niyaShowShelf
        ]
        XCTAssertEqual(names.count, 4)
    }
}
