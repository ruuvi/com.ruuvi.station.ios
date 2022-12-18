import RuuviRepository
import Foundation

extension RuuviRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ruuviStorage(let error):
            return error.errorDescription
        case .ruuviPool(let error):
            return error.errorDescription
        }
    }
}
