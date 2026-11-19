import Foundation

public enum CloudGraphError: LocalizedError {
    case invalid(String)
    case unavailable
    case unauthorized
    case http(status: Int, retryAfter: TimeInterval?)

    public var errorDescription: String? {
        switch self {
        case .invalid: return "The cloud returned an invalid graph response."
        case .unavailable: return "Cloud graph history is not available on this server yet."
        case .unauthorized: return "Sign in again to load cloud history."
        case .http(let status, _):
            switch status {
            case 401, 403: return "Cloud history is no longer accessible. Sign in or check sensor access."
            case 413: return "This history range is too large. Select a shorter duration and try again."
            case 429, 503: return "Cloud history is busy. Please try again shortly."
            default: return "Cloud history could not be loaded. Please try again."
            }
        }
    }
}
