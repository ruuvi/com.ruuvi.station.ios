import Foundation
import RuuviReactor
import Localize_Swift

extension RuuviReactorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ruuviPersistence(let error):
            return error.errorDescription
        }
    }
}
