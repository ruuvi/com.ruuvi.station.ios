import Foundation
import RuuviPool

extension RuuviPoolError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .ruuviPersistence(error):
            error.errorDescription
        }
    }
}
