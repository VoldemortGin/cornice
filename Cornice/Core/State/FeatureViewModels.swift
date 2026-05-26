import SwiftUI

/// Container that holds all feature ViewModels as long-lived instances.
/// Created once at the top level and passed down to all state views,
/// ensuring feature state (playback position, clipboard entries, etc.)
/// survives notch state transitions.
@MainActor
@Observable
final class FeatureViewModels {
    let media = MediaPlayerViewModel()
    let calendar = CalendarViewModel()
    let monitor = SystemMonitorViewModel()
    let shelf = FileShelfViewModel()
    let clipboard = ClipboardHistoryViewModel()
    let quickApps = QuickAppsViewModel()
}
