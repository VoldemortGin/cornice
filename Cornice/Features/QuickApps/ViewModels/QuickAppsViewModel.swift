import SwiftUI
import AppKit
import Defaults

@MainActor
@Observable
final class QuickAppsViewModel {
    private static let maxApps = 12

    var apps: [QuickAppEntry] {
        get { Defaults[.quickApps] }
        set { Defaults[.quickApps] = newValue }
    }

    var canAddMore: Bool {
        apps.count < Self.maxApps
    }

    func addApp(from url: URL) {
        guard canAddMore else { return }
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier,
              let name = bundle.infoDictionary?["CFBundleName"] as? String
                ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                ?? url.deletingPathExtension().lastPathComponent as String?
        else { return }

        guard !apps.contains(where: { $0.bundleIdentifier == bundleID }) else { return }

        let entry = QuickAppEntry(
            bundleIdentifier: bundleID,
            name: name,
            order: apps.count
        )
        apps.append(entry)
    }

    func removeApp(_ app: QuickAppEntry) {
        apps.removeAll { $0.id == app.id }
        reindex()
    }

    func move(from source: IndexSet, to destination: Int) {
        apps.move(fromOffsets: source, toOffset: destination)
        reindex()
    }

    func launch(_ app: QuickAppEntry) {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: app.bundleIdentifier
        ) else { return }

        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error {
                Log.general.error("Failed to launch \(app.name): \(error.localizedDescription)")
            }
        }
    }

    func icon(for app: QuickAppEntry) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: app.bundleIdentifier
        ) else {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func isRunning(_ app: QuickAppEntry) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == app.bundleIdentifier
        }
    }

    func showFilePicker() -> URL? {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    // MARK: - Private

    private func reindex() {
        for i in apps.indices {
            apps[i].order = i
        }
    }
}
