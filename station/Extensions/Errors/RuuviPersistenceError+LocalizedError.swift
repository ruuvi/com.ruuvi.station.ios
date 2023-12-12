import Foundation
import RuuviLocalization
import RuuviPersistence

extension RuuviPersistenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .grdb(error):
            error.localizedDescription
        case let .realm(error):
            error.localizedDescription
        case .failedToFindRuuviTag:
            RuuviLocalization.RuuviPersistenceError.failedToFindRuuviTag
        }
    }
}
