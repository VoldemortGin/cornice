import Foundation

enum AirDropState: Equatable {
    case idle
    case ready
    case sending
    case completed
    case failed(String)

    static func == (lhs: AirDropState, rhs: AirDropState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.ready, .ready), (.sending, .sending), (.completed, .completed):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

enum AirDropResult {
    case success
    case cancelled
    case failed(Error)
}

enum AirDropError: LocalizedError {
    case unavailable
    case noContent
    case bookmarkResolutionFailed(Error)
    case transferFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "AirDrop is not available. Check that AirDrop is enabled in System Settings."
        case .noContent:
            return "No content to share."
        case .bookmarkResolutionFailed(let error):
            return "Could not access the file: \(error.localizedDescription)"
        case .transferFailed(let error):
            return "AirDrop transfer failed: \(error.localizedDescription)"
        }
    }
}
