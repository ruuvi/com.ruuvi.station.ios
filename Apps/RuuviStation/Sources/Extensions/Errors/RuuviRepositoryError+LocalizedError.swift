import Foundation
import RuuviRepository

extension RuuviRepositoryError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .ruuviStorage(error):
            error.errorDescription
        case let .ruuviPool(error):
            error.errorDescription
        }
    }
}
