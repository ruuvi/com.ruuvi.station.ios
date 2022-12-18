import Foundation
import RuuviPersistence

extension RuuviPersistenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .grdb(let error):
            return error.localizedDescription
        case .realm(let error):
            return error.localizedDescription
        case .failedToFindRuuviTag:
            return "RuuviPersistenceError.failedToFindRuuviTag".localized()
        }
    }
}
