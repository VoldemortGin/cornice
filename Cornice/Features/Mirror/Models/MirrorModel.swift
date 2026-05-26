import Foundation

enum CameraState: Equatable, Sendable {
    case idle
    case authorized
    case denied
    case unavailable
    case active
}
