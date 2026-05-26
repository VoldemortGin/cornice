import SwiftUI
import UniformTypeIdentifiers

struct FileShelfView: View {
    @Bindable var viewModel: FileShelfViewModel
    var onAirDropRequest: (([ShelfItem]) -> Void)?

    @State private var isDropTargeted = false
    @State private var selectedItemIDs: Set<UUID> = []

    var body: some View {
        HStack(spacing: 0) {
            if viewModel.items.isEmpty {
                emptyStateView
            } else {
                shelfItemsView
            }

            Divider()
                .opacity(0.3)
                .padding(.vertical, 8)

            AirDropZoneView(
                onDrop: { items in
                    let selectedItems = viewModel.items.filter { selectedItemIDs.contains($0.id) }
                    let toDrop = selectedItems.isEmpty ? items : selectedItems
                    onAirDropRequest?(toDrop)
                },
                isEmpty: viewModel.items.isEmpty
            )
            .frame(width: 80)
        }
        .frame(minHeight: 88)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDropTargeted ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isDropTargeted ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
        .onDrop(of: [.fileURL, .url, .utf8PlainText], isTargeted: $isDropTargeted) { providers in
            Task {
                await viewModel.handleDrop(providers: providers)
            }
            return true
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("Drag files, text, or links here")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("They'll be waiting when you need them")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var shelfItemsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(viewModel.items) { item in
                    ShelfItemCard(
                        item: item,
                        isSelected: selectedItemIDs.contains(item.id),
                        onRemove: { viewModel.removeItem(item) },
                        onTap: { toggleSelection(item.id) }
                    )
                    .onDrag {
                        viewModel.itemProvider(for: item)
                    }
                    .contextMenu {
                        itemContextMenu(for: item)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    @ViewBuilder
    private func itemContextMenu(for item: ShelfItem) -> some View {
        Button("Copy") {
            copyItem(item)
        }
        if case .file = item.kind {
            Button("Copy Path") {
                copyPath(item)
            }
        }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin") {
            if item.isPinned {
                viewModel.unpinItem(id: item.id)
            } else {
                viewModel.pinItem(id: item.id)
            }
        }
        Divider()
        Button("Remove from Shelf", role: .destructive) {
            viewModel.removeItem(item)
        }
    }

    private func copyItem(_ item: ShelfItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .file(let bookmark):
            if let (url, _) = try? BookmarkService().resolveBookmark(bookmark) {
                pb.writeObjects([url as NSURL])
            }
        case .text(let string):
            pb.setString(string, forType: .string)
        case .link(let url):
            pb.writeObjects([url as NSURL])
        }
    }

    private func copyPath(_ item: ShelfItem) {
        guard case .file(let bookmark) = item.kind,
              let (url, _) = try? BookmarkService().resolveBookmark(bookmark) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }
}

// MARK: - ShelfItemCard

struct ShelfItemCard: View {
    let item: ShelfItem
    let isSelected: Bool
    let onRemove: () -> Void
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                itemIcon
                    .frame(width: 48, height: 48)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white, .red)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                        .offset(x: -4, y: -4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }

            Text(item.name)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 64)

            typeBadge
        }
        .frame(width: 72, height: 88)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }

    @ViewBuilder
    private var itemIcon: some View {
        switch item.kind {
        case .file:
            Image(systemName: "doc.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
        case .text:
            Image(systemName: "doc.text.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
        case .link:
            Image(systemName: "link")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
        }
    }

    private var typeBadge: some View {
        Circle()
            .fill(badgeColor)
            .frame(width: 6, height: 6)
    }

    private var badgeColor: Color {
        switch item.kind {
        case .file: return .blue
        case .text: return .green
        case .link: return .orange
        }
    }
}

// MARK: - AirDrop Zone (for integration inside FileShelf)

struct AirDropZoneView: View {
    let onDrop: ([ShelfItem]) -> Void
    let isEmpty: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 20))
                .foregroundStyle(isHovered ? .blue : .secondary)
                .scaleEffect(isHovered ? 1.1 : 1.0)

            Text("AirDrop")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.blue.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
