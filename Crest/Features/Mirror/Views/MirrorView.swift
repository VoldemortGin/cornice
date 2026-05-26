import SwiftUI
import AVFoundation
import Defaults

struct CameraPreviewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession
    let isMirrored: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill

        if let connection = previewLayer.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }

        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.wantsLayer = true
        view.layer = previewLayer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let previewLayer = nsView.layer as? AVCaptureVideoPreviewLayer else { return }
        if let connection = previewLayer.connection {
            connection.isVideoMirrored = isMirrored
        }
    }
}

struct MirrorView: View {
    let cameraService: CameraService
    let isCompact: Bool

    @Default(.mirrorFlipped) private var isMirrored

    var body: some View {
        Group {
            switch cameraService.state {
            case .idle:
                placeholder(message: "Initializing...", icon: "camera")
                    .onAppear {
                        cameraService.checkPermission()
                    }

            case .authorized, .active:
                if let session = cameraService.session {
                    CameraPreviewRepresentable(session: session, isMirrored: isMirrored)
                        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 8 : 12))
                        .onAppear { cameraService.start() }
                        .onDisappear { cameraService.stop() }
                } else {
                    placeholder(message: "No Camera", icon: "camera.metering.unknown")
                }

            case .denied:
                deniedView

            case .unavailable:
                placeholder(message: "No Camera Available", icon: "camera.fill")
            }
        }
        .frame(
            width: isCompact ? 80 : 200,
            height: isCompact ? 60 : 150
        )
    }

    private var deniedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Camera Access Denied")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.caption2)
        }
    }

    private func placeholder(message: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
