import Foundation
import RuuviStorage

extension RuuviStorageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .ruuviPersistence(error):
            error.errorDescription
        }
    }
}
