import Foundation

enum RUError: Error {
    case persistence(Error)
}

extension RUError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .persistence(let error):
            return error.localizedDescription
        }
    }
}
