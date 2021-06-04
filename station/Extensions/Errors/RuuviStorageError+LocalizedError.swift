import Foundation
import RuuviStorage
import Localize_Swift

extension RuuviStorageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ruuviPersistence(let error):
            return error.errorDescription
        }
    }
}
