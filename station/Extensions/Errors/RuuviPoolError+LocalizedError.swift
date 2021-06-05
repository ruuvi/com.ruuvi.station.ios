import Foundation
import RuuviPool
import Localize_Swift

extension RuuviPoolError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ruuviPersistence(let error):
            return error.errorDescription
        }
    }
}
