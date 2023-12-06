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
        case (.loading(let lhsMessage), .loading(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.success(let lhsMessage), .success(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.failed(let lhsMessage), .failed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.dismiss, .dismiss):
            return true
        default:
            return false
        }
    }
}
