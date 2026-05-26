import AppIntents

struct ToggleNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Niya"
    static var description: IntentDescription = "Toggle the Niya notch between open and closed."

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .niyaToggleNotch, object: nil)
        }
        return .result()
    }
}

struct ShowNowPlayingIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Now Playing"
    static var description: IntentDescription = "Open Niya and show the Now Playing widget."

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .niyaShowNowPlaying, object: nil)
        }
        return .result()
    }
}

struct ShowCalendarIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Calendar"
    static var description: IntentDescription = "Open Niya and show upcoming calendar events."

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .niyaShowCalendar, object: nil)
        }
        return .result()
    }
}

struct ShowShelfIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Shelf"
    static var description: IntentDescription = "Open Niya and show the file shelf."

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .niyaShowShelf, object: nil)
        }
        return .result()
    }
}

struct CrestShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleNotchIntent(),
            phrases: ["Toggle \(.applicationName)", "Open \(.applicationName)"],
            shortTitle: "Toggle Niya",
            systemImageName: "rectangle.topthird.inset.filled"
        )
        AppShortcut(
            intent: ShowNowPlayingIntent(),
            phrases: ["Show Now Playing in \(.applicationName)"],
            shortTitle: "Now Playing",
            systemImageName: "music.note"
        )
        AppShortcut(
            intent: ShowCalendarIntent(),
            phrases: ["Show Calendar in \(.applicationName)"],
            shortTitle: "Calendar",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: ShowShelfIntent(),
            phrases: ["Show Shelf in \(.applicationName)"],
            shortTitle: "Shelf",
            systemImageName: "tray"
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let niyaToggleNotch = Notification.Name("com.niya.toggleNotch")
    static let niyaShowNowPlaying = Notification.Name("com.niya.showNowPlaying")
    static let niyaShowCalendar = Notification.Name("com.niya.showCalendar")
    static let niyaShowShelf = Notification.Name("com.niya.showShelf")
}
