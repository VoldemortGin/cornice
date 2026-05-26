import AppKit
import os

private let log = Logger(subsystem: "com.cornice.app", category: "clipboard")

final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pollInterval: TimeInterval
    private var isRestoring: Bool = false
    private var isPaused: Bool = false

    var onClipboardChange: ((ClipboardEntry) -> Void)?

    var excludedBundleIDs: Set<String> = [
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.apple.keychainaccess",
        "com.lastpass.LastPass",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.dashlane.Dashlane"
    ]

    init(pollInterval: TimeInterval = 0.5) {
        self.pollInterval = pollInterval
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        stopMonitoring()
        isPaused = false
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func pauseMonitoring() {
        isPaused = true
    }

    func resumeMonitoring() {
        isPaused = false
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func markAsRestoring() {
        isRestoring = true
    }

    func clearRestoringFlag() {
        isRestoring = false
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func checkForChanges() {
        guard !isPaused else { return }

        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        guard !isRestoring else {
            isRestoring = false
            return
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication
        let sourceBundleID = sourceApp?.bundleIdentifier

        if let bundleID = sourceBundleID, excludedBundleIDs.contains(bundleID) {
            log.info("Skipping clipboard from excluded app: \(bundleID)")
            return
        }

        let pasteboard = NSPasteboard.general
        guard let types = pasteboard.types, !types.isEmpty else { return }

        // Check for concealed type (password managers)
        if types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) ||
           types.contains(NSPasteboard.PasteboardType("concealed")) {
            log.info("Skipping concealed pasteboard content")
            return
        }

        guard let entry = extractEntry(from: pasteboard, sourceApp: sourceApp) else { return }

        // Sensitive content detection
        if let text = entry.textContent {
            if isSensitiveContent(text) {
                log.info("Skipping sensitive content detected in clipboard")
                return
            }
        }

        onClipboardChange?(entry)
    }

    private func extractEntry(from pasteboard: NSPasteboard, sourceApp: NSRunningApplication?) -> ClipboardEntry? {
        let types = pasteboard.types ?? []
        let sourceBundleID = sourceApp?.bundleIdentifier
        let sourceAppName = sourceApp?.localizedName

        // Priority 1: File URLs
        if types.contains(.fileURL) {
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
                let fileURLs = urls.filter { $0.isFileURL }
                if !fileURLs.isEmpty {
                    let truncated = Array(fileURLs.prefix(100))
                    return ClipboardEntry(
                        id: UUID(),
                        timestamp: Date(),
                        contentType: .fileURL,
                        textContent: nil,
                        imageData: nil,
                        fileURLs: truncated,
                        sourceAppBundleID: sourceBundleID,
                        sourceAppName: sourceAppName,
                        isPinned: false,
                        isTruncated: fileURLs.count > 100
                    )
                }
            }
        }

        // Priority 2: Images
        if types.contains(.tiff) || types.contains(.png) {
            let imageType: NSPasteboard.PasteboardType = types.contains(.png) ? .png : .tiff
            if let imageData = pasteboard.data(forType: imageType) {
                let thumbnail = generateThumbnail(from: imageData)
                return ClipboardEntry(
                    id: UUID(),
                    timestamp: Date(),
                    contentType: .image,
                    textContent: nil,
                    imageData: thumbnail,
                    fileURLs: nil,
                    sourceAppBundleID: sourceBundleID,
                    sourceAppName: sourceAppName,
                    isPinned: false,
                    isTruncated: false
                )
            }
        }

        // Priority 3: Rich text
        if types.contains(.rtf) || types.contains(.rtfd) {
            if let text = pasteboard.string(forType: .string) {
                let truncated = String(text.prefix(50_000))
                return ClipboardEntry(
                    id: UUID(),
                    timestamp: Date(),
                    contentType: .richText,
                    textContent: truncated,
                    imageData: nil,
                    fileURLs: nil,
                    sourceAppBundleID: sourceBundleID,
                    sourceAppName: sourceAppName,
                    isPinned: false,
                    isTruncated: text.count > 50_000
                )
            }
        }

        // Priority 4: Plain text
        if types.contains(.string) {
            if let text = pasteboard.string(forType: .string) {
                let truncated = String(text.prefix(50_000))
                return ClipboardEntry(
                    id: UUID(),
                    timestamp: Date(),
                    contentType: .text,
                    textContent: truncated,
                    imageData: nil,
                    fileURLs: nil,
                    sourceAppBundleID: sourceBundleID,
                    sourceAppName: sourceAppName,
                    isPinned: false,
                    isTruncated: text.count > 50_000
                )
            }
        }

        return nil
    }

    private func generateThumbnail(from imageData: Data) -> Data? {
        guard let image = NSImage(data: imageData) else { return nil }

        let maxSize: CGFloat = 256
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        let scale: CGFloat
        if originalSize.width > originalSize.height {
            scale = maxSize / originalSize.width
        } else {
            scale = maxSize / originalSize.height
        }

        let targetSize = NSSize(
            width: min(originalSize.width * scale, maxSize),
            height: min(originalSize.height * scale, maxSize)
        )

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        guard let tiffData = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }

        return jpegData
    }

    // MARK: - Sensitive Content Detection

    func isSensitiveContent(_ text: String) -> Bool {
        isCreditCard(text) || isSSN(text)
    }

    func isCreditCard(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber)
        return digits.count >= 13 && digits.count <= 16
    }

    func isSSN(_ text: String) -> Bool {
        text.range(of: #"^\d{3}-\d{2}-\d{4}$"#, options: .regularExpression) != nil
    }
}
