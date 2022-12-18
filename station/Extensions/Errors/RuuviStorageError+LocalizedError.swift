import Foundation
import RuuviStorage

extension RuuviStorageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ruuviPersistence(let error):
            return error.errorDescription
        }
    }
}
