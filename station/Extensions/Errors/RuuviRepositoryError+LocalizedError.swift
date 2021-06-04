import RuuviRepository
import Foundation
import Localize_Swift

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
