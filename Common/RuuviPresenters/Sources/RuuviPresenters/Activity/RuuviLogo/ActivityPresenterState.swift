import Foundation

public enum ActivityPresenterState: Equatable {
    case loading(message: String?)
    case success(message: String?)
    case failed(message: String?)
    case dismiss

    public static func == (
        lhs: ActivityPresenterState,
        rhs: ActivityPresenterState
    ) -> Bool {
        switch (lhs, rhs) {
        case let (.loading(lhsMessage), .loading(rhsMessage)):
            lhsMessage == rhsMessage
        case let (.success(lhsMessage), .success(rhsMessage)):
            lhsMessage == rhsMessage
        case let (.failed(lhsMessage), .failed(rhsMessage)):
            lhsMessage == rhsMessage
        case (.dismiss, .dismiss):
            true
        default:
            false
        }
    }
}
