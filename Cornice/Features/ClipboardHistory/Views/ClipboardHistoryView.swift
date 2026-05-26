import SwiftUI

struct ClipboardHistoryView: View {
    @Bindable var viewModel: ClipboardHistoryViewModel

    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().opacity(0.3)

            if viewModel.isMonitoringPaused {
                pausedBanner
            }

            if viewModel.entries.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .frame(minWidth: 350, minHeight: 200)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .top) {
            if viewModel.showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showCopiedToast)
        .alert("Clear Clipboard History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearAll()
            }
        } message: {
            Text("Clear all clipboard history? Pinned items will be kept.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            searchField
            Spacer()
            pauseButton
            clearButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            TextField("Search clipboard...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: 200)
    }

    private var pauseButton: some View {
        Button {
            if viewModel.isMonitoringPaused {
                viewModel.resumeMonitoring()
            } else {
                viewModel.pauseMonitoring()
            }
        } label: {
            Image(systemName: viewModel.isMonitoringPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 11))
                .foregroundStyle(viewModel.isMonitoringPaused ? .orange : .secondary)
        }
        .buttonStyle(.plain)
        .help(viewModel.isMonitoringPaused ? "Resume monitoring" : "Pause monitoring")
    }

    private var clearButton: some View {
        Button {
            showClearConfirmation = true
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Clear all history")
    }

    // MARK: - Paused Banner

    private var pausedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))
            Text("Monitoring paused")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Resume") {
                viewModel.resumeMonitoring()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.05))
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 2) {
                if !viewModel.pinnedEntries.isEmpty && viewModel.searchQuery.isEmpty {
                    pinnedSection
                }
                historySection
            }
            .padding(.vertical, 4)
        }
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Pinned")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 4)

            ForEach(viewModel.pinnedEntries) { entry in
                ClipboardEntryRow(
                    entry: entry,
                    onCopy: { viewModel.copyToClipboard(entry: entry) },
                    onPin: { viewModel.unpinEntry(id: entry.id) },
                    onDelete: { viewModel.removeEntry(id: entry.id) },
                    isPinned: true
                )
            }
        }
    }

    private var historySection: some View {
        ForEach(viewModel.filteredEntries.filter { !$0.isPinned }) { entry in
            ClipboardEntryRow(
                entry: entry,
                onCopy: { viewModel.copyToClipboard(entry: entry) },
                onPin: { viewModel.pinEntry(id: entry.id) },
                onDelete: { viewModel.removeEntry(id: entry.id) },
                isPinned: false
            )
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No clipboard history yet")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Copy something to get started")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Toast

    private var copiedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 12))
            Text("Copied to clipboard")
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.top, 8)
    }
}

// MARK: - Entry Row

struct ClipboardEntryRow: View {
    let entry: ClipboardEntry
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    let isPinned: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            sourceAppIcon
            contentPreview
            Spacer()
            timestampLabel
            actionButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in isHovered = hovering }
        .onTapGesture { onCopy() }
        .contextMenu {
            Button("Copy") { onCopy() }
            Button(isPinned ? "Unpin" : "Pin") { onPin() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var sourceAppIcon: some View {
        Group {
            if let bundleID = entry.sourceAppBundleID,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "clipboard")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch entry.contentType {
        case .text, .richText:
            Text(entry.previewText)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(.primary)
        case .image:
            if let imageData = entry.imageData, let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("Image")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .fileURL:
            Text(entry.previewText)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
    }

    private var timestampLabel: some View {
        Text(relativeTimestamp(entry.timestamp))
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isHovered {
            HStack(spacing: 4) {
                Button(action: onPin) {
                    Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isPinned ? .orange : .secondary)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func relativeTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60)) min ago" }
        if interval < 86400 { return "\(Int(interval / 3600)) hour\(Int(interval / 3600) == 1 ? "" : "s") ago" }
        if interval < 172800 { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
