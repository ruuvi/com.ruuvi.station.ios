import Foundation
import RuuviPool

extension RuuviPoolError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ruuviPersistence(let error):
            return error.errorDescription
        }
    }
}
