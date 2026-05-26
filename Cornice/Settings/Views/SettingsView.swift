import SwiftUI
import Defaults
import LaunchAtLogin
import KeyboardShortcuts

// MARK: - Settings Sections

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case media
    case calendar
    case huds
    case battery
    case shelf
    case clipboard
    case shortcuts
    case quickApps
    case mirror
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .media: "Media"
        case .calendar: "Calendar"
        case .huds: "HUDs"
        case .battery: "Battery"
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .shortcuts: "Shortcuts"
        case .quickApps: "Quick Apps"
        case .mirror: "Mirror"
        case .advanced: "Advanced"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .general: "gear"
        case .appearance: "paintbrush"
        case .media: "music.note"
        case .calendar: "calendar"
        case .huds: "speaker.wave.2"
        case .battery: "battery.75percent"
        case .shelf: "tray"
        case .clipboard: "doc.on.clipboard"
        case .shortcuts: "command"
        case .quickApps: "square.grid.2x2"
        case .mirror: "camera"
        case .advanced: "wrench.and.screwdriver"
        case .about: "info.circle"
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var selectedSection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            ScrollView {
                detailView(for: selectedSection)
                    .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 500)
    }

    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .general: GeneralSettingsView()
        case .appearance: AppearanceSettingsView()
        case .media: MediaSettingsView()
        case .calendar: CalendarSettingsView()
        case .huds: HUDSettingsView()
        case .battery: BatterySettingsView()
        case .shelf: ShelfSettingsView()
        case .clipboard: ClipboardSettingsView()
        case .shortcuts: ShortcutsSettingsView()
        case .quickApps: QuickAppsSettingsView()
        case .mirror: MirrorSettingsView()
        case .advanced: AdvancedSettingsView()
        case .about: AboutSettingsView()
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Default(.menubarIcon) private var menubarIcon
    @Default(.activationMethod) private var activationMethod
    @Default(.hoverDelay) private var hoverDelay
    @Default(.closeDelay) private var closeDelay
    @Default(.showOnAllDisplays) private var showOnAllDisplays

    var body: some View {
        Form {
            Section("Startup") {
                LaunchAtLogin.Toggle("Launch at login")
            }

            Section("Menu Bar") {
                Toggle("Show menu bar icon", isOn: $menubarIcon)
            }

            Section("Activation") {
                Picker("Activation method", selection: $activationMethod) {
                    Text("Hover").tag(ActivationMethod.hover)
                    Text("Click").tag(ActivationMethod.click)
                    Text("Swipe").tag(ActivationMethod.swipe)
                }
                .pickerStyle(.segmented)

                if activationMethod == .hover {
                    HStack {
                        Text("Hover delay")
                        Slider(value: $hoverDelay, in: 0.1...0.5, step: 0.05)
                        Text("\(Int(hoverDelay * 1000))ms")
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                    }
                }

                HStack {
                    Text("Close delay")
                    Slider(value: $closeDelay, in: 0.2...1.0, step: 0.1)
                    Text("\(Int(closeDelay * 1000))ms")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
            }

            Section("Display") {
                Toggle("Show on all displays", isOn: $showOnAllDisplays)
            }

            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder("Toggle Niya:", name: .toggleNiya)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @Default(.notchHeightMode) private var notchHeightMode
    @Default(.customNotchHeight) private var customNotchHeight
    @Default(.theme) private var theme

    var body: some View {
        Form {
            Section("Notch Size") {
                Picker("Height mode", selection: $notchHeightMode) {
                    Text("Match Notch").tag(NotchHeightSetting.matchNotch)
                    Text("Match Menu Bar").tag(NotchHeightSetting.matchMenuBar)
                    Text("Custom").tag(NotchHeightSetting.custom)
                }

                if notchHeightMode == .custom {
                    HStack {
                        Text("Custom height")
                        Slider(value: $customNotchHeight, in: 20...60, step: 1)
                        Text("\(Int(customNotchHeight))pt")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            Section("Theme") {
                Picker("Appearance", selection: $theme) {
                    Text("System").tag(ThemeSetting.system)
                    Text("Always Dark").tag(ThemeSetting.dark)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Media Settings

struct MediaSettingsView: View {
    @Default(.musicSource) private var musicSource
    @Default(.showVisualizer) private var showVisualizer
    @Default(.sneakPeekOnTrackChange) private var sneakPeekOnTrackChange
    @Default(.sneakPeekDuration) private var sneakPeekDuration

    var body: some View {
        Form {
            Section("Source") {
                Picker("Music source", selection: $musicSource) {
                    Text("Now Playing (System)").tag(MusicSourceSetting.nowPlaying)
                    Text("Apple Music").tag(MusicSourceSetting.appleMusic)
                    Text("Spotify").tag(MusicSourceSetting.spotify)
                }
            }

            Section("Visualizer") {
                Toggle("Show audio visualizer", isOn: $showVisualizer)
            }

            Section("Sneak Peek") {
                Toggle("Show on track change", isOn: $sneakPeekOnTrackChange)

                if sneakPeekOnTrackChange {
                    HStack {
                        Text("Duration")
                        Slider(value: $sneakPeekDuration, in: 1.0...8.0, step: 0.5)
                        Text("\(sneakPeekDuration, specifier: "%.1f")s")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Calendar Settings

struct CalendarSettingsView: View {
    @Default(.showCalendar) private var showCalendar
    @Default(.calendarLookahead) private var calendarLookahead
    @Default(.showAllDayEvents) private var showAllDayEvents
    @Default(.showDeclinedEvents) private var showDeclinedEvents

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show calendar widget", isOn: $showCalendar)
            }

            if showCalendar {
                Section("Events") {
                    HStack {
                        Text("Lookahead")
                        Slider(
                            value: Binding(
                                get: { Double(calendarLookahead) },
                                set: { calendarLookahead = Int($0) }
                            ),
                            in: 1...72,
                            step: 1
                        )
                        Text("\(calendarLookahead)h")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                    Toggle("Show all-day events", isOn: $showAllDayEvents)
                    Toggle("Show declined events", isOn: $showDeclinedEvents)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - HUD Settings

struct HUDSettingsView: View {
    @Default(.hudReplacementEnabled) private var hudReplacementEnabled
    @Default(.replaceVolumeHUD) private var replaceVolumeHUD
    @Default(.replaceBrightnessHUD) private var replaceBrightnessHUD
    @Default(.replaceKeyboardHUD) private var replaceKeyboardHUD
    @Default(.hudDuration) private var hudDuration
    @Default(.hudShowPercentage) private var hudShowPercentage

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable HUD replacement", isOn: $hudReplacementEnabled)
                    .help("Replace system volume/brightness HUDs with Niya's notch HUD.")
            }

            if hudReplacementEnabled {
                Section("Replace") {
                    Toggle("Volume HUD", isOn: $replaceVolumeHUD)
                    Toggle("Brightness HUD", isOn: $replaceBrightnessHUD)
                    Toggle("Keyboard Backlight HUD", isOn: $replaceKeyboardHUD)
                }

                Section("Appearance") {
                    HStack {
                        Text("Duration")
                        Slider(value: $hudDuration, in: 0.5...4.0, step: 0.25)
                        Text("\(hudDuration, specifier: "%.2f")s")
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                    }
                    Toggle("Show percentage label", isOn: $hudShowPercentage)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Battery Settings

struct BatterySettingsView: View {
    var body: some View {
        Form {
            Section("Battery") {
                Text("Battery status is shown automatically in the notch when relevant (low battery, charging state changes).")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shelf Settings

struct ShelfSettingsView: View {
    @Default(.shelfEnabled) private var shelfEnabled
    @Default(.shelfMaxItems) private var shelfMaxItems

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable file shelf", isOn: $shelfEnabled)
                    .help("Drag files onto the notch to temporarily store them.")
            }

            if shelfEnabled {
                Section("Limits") {
                    HStack {
                        Text("Max items")
                        Slider(
                            value: Binding(
                                get: { Double(shelfMaxItems) },
                                set: { shelfMaxItems = Int($0) }
                            ),
                            in: 5...50,
                            step: 5
                        )
                        Text("\(shelfMaxItems)")
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Clipboard Settings

struct ClipboardSettingsView: View {
    @Default(.clipboardEnabled) private var clipboardEnabled
    @Default(.clipboardMaxEntries) private var clipboardMaxEntries

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable clipboard history", isOn: $clipboardEnabled)
            }

            if clipboardEnabled {
                Section("Limits") {
                    HStack {
                        Text("Max entries")
                        Slider(
                            value: Binding(
                                get: { Double(clipboardMaxEntries) },
                                set: { clipboardMaxEntries = Int($0) }
                            ),
                            in: 10...200,
                            step: 10
                        )
                        Text("\(clipboardMaxEntries)")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @Default(.shortcutsEnabled) private var shortcutsEnabled
    @Default(.shortcuts) private var shortcuts
    @State private var newShortcutName = ""
    @State private var newShortcutIcon = "command"

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable shortcuts widget", isOn: $shortcutsEnabled)
            }

            if shortcutsEnabled {
                Section("Configured Shortcuts") {
                    if shortcuts.isEmpty {
                        Text("No shortcuts configured. Add Apple Shortcuts below.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(shortcuts) { shortcut in
                            HStack {
                                Image(systemName: shortcut.iconSystemName ?? "command")
                                    .frame(width: 20)
                                Text(shortcut.name)
                                Spacer()
                                Button(role: .destructive) {
                                    shortcuts.removeAll { $0.id == shortcut.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Add Shortcut") {
                    TextField("Shortcut name (from Shortcuts.app)", text: $newShortcutName)
                    TextField("SF Symbol name", text: $newShortcutIcon)
                        .help("e.g. \"command\", \"house\", \"star.fill\"")

                    Button("Add") {
                        let entry = ShortcutEntry(
                            name: newShortcutName,
                            iconSystemName: newShortcutIcon.isEmpty ? nil : newShortcutIcon,
                            order: shortcuts.count
                        )
                        shortcuts.append(entry)
                        newShortcutName = ""
                        newShortcutIcon = "command"
                    }
                    .disabled(newShortcutName.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Quick Apps Settings

struct QuickAppsSettingsView: View {
    @Default(.quickAppsEnabled) private var quickAppsEnabled
    @Default(.quickApps) private var quickApps

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable quick apps launcher", isOn: $quickAppsEnabled)
            }

            if quickAppsEnabled {
                Section("Pinned Apps (\(quickApps.count)/12)") {
                    if quickApps.isEmpty {
                        Text("No apps pinned. Use the + button in the notch to add apps.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(quickApps) { app in
                            HStack {
                                Text(app.name)
                                Spacer()
                                Text(app.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button(role: .destructive) {
                                    quickApps.removeAll { $0.id == app.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Mirror Settings

struct MirrorSettingsView: View {
    @Default(.mirrorEnabled) private var mirrorEnabled
    @Default(.mirrorFlipped) private var mirrorFlipped

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable camera mirror", isOn: $mirrorEnabled)
                    .help("Show a small camera preview in the notch.")
            }

            if mirrorEnabled {
                Section("Display") {
                    Toggle("Mirror image (flip horizontally)", isOn: $mirrorFlipped)
                }

                Section {
                    Text("The camera is only active when the mirror widget is visible. No video is recorded or stored.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @Default(.debugMode) private var debugMode

    var body: some View {
        Form {
            Section("Debug") {
                Toggle("Enable debug mode", isOn: $debugMode)
                    .help("Show debug overlays and additional logging.")
            }

            Section("Reset") {
                Button("Reset All Settings", role: .destructive) {
                    Defaults.removeAll()
                }
                .help("Reset all settings to their default values.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.system(size: 48))
                .foregroundStyle(.primary)

            Text("Cornice")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("A dynamic island for your Mac.")
                .font(.body)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Link("Website", destination: URL(string: "https://niya.app")!)
                Link("GitHub", destination: URL(string: "https://github.com/niya-app")!)
            }
            .font(.callout)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Keyboard Shortcut Registration

extension KeyboardShortcuts.Name {
    static let toggleNiya = Self("toggleNiya")
}
