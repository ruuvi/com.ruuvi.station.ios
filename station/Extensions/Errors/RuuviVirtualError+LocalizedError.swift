import Foundation
import RuuviVirtual
import Localize_Swift

extension VirtualReactorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .virtualPersistence(let error):
            return error.localizedDescription
        }
    }
}

extension VirtualPersistenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .persistence(let error):
            return error.localizedDescription
        case .failedToFindVirtualTag:
            return "UnexpectedError.failedToFindVirtualTag".localized()
        }
    }
}

extension VirtualRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .virtualPersistence(let error):
            return error.localizedDescription
        }
    }
}

extension VirtualStorageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .virtualPersistence(let error):
            return error.localizedDescription
        }
    }
}
