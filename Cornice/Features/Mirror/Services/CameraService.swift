import AVFoundation
import AppKit

@MainActor
@Observable
final class CameraService {
    private(set) var state: CameraState = .idle
    private(set) var session: AVCaptureSession?

    private var captureDevice: AVCaptureDevice?

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            state = .authorized
            setupSession()
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .unavailable
        }
    }

    func start() {
        guard state == .authorized || state == .active else { return }
        guard let session, !session.isRunning else { return }

        Task.detached { [session] in
            session.startRunning()
        }
        state = .active
    }

    func stop() {
        guard let session, session.isRunning else { return }

        Task.detached { [session] in
            session.stopRunning()
        }
        state = .authorized
    }

    // MARK: - Private

    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if granted {
                    self.state = .authorized
                    self.setupSession()
                } else {
                    self.state = .denied
                }
            }
        }
    }

    private func setupSession() {
        guard session == nil else { return }

        let newSession = AVCaptureSession()
        newSession.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            state = .unavailable
            return
        }

        captureDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if newSession.canAddInput(input) {
                newSession.addInput(input)
            }
        } catch {
            Log.general.error("Failed to create camera input: \(error.localizedDescription)")
            state = .unavailable
            return
        }

        session = newSession
    }
}
