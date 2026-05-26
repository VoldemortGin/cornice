import SwiftUI

struct QuickAppsView: View {
    let viewModel: QuickAppsViewModel

    var body: some View {
        HStack(spacing: 12) {
            ForEach(viewModel.apps) { app in
                quickAppButton(for: app)
            }

            if viewModel.canAddMore {
                addButton
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func quickAppButton(for app: QuickAppEntry) -> some View {
        Button {
            viewModel.launch(app)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: viewModel.icon(for: app))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)

                    if viewModel.isRunning(app) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                            .offset(x: 2, y: 2)
                    }
                }

                Text(app.name)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove", role: .destructive) {
                viewModel.removeApp(app)
            }
        }
    }

    private var addButton: some View {
        Button {
            if let url = viewModel.showFilePicker() {
                viewModel.addApp(from: url)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text("Add")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
