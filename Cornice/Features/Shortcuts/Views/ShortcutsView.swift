import SwiftUI
import Defaults

struct ShortcutsView: View {
    @Default(.shortcuts) private var shortcuts

    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(shortcuts) { shortcut in
                shortcutButton(for: shortcut)
            }
        }
        .padding(8)
    }

    private func shortcutButton(for shortcut: ShortcutEntry) -> some View {
        Button {
            runShortcut(shortcut)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: shortcut.iconSystemName ?? "command")
                    .font(.title3)
                    .foregroundStyle(.white)

                Text(shortcut.name)
                    .font(.system(size: 10))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 72, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func runShortcut(_ shortcut: ShortcutEntry) {
        let encodedName = shortcut.name.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? shortcut.name

        guard let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)") else { return }
        NSWorkspace.shared.open(url)
    }
}
