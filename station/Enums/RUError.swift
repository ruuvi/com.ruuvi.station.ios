import Foundation

enum RUError: Error {
    case core(CoreError)
    case persistence(Error)
}

extension RUError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .core(let error):
            return error.localizedDescription
        case .persistence(let error):
            return error.localizedDescription
        }
    }
}

enum CoreError: Error {
    case failedToGetPngRepresentation
}

extension CoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToGetPngRepresentation:
            return "CoreError.failedToGetPngRepresentation".localized()
        }
    }
}
