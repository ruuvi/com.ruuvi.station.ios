import Foundation
import RuuviReactor

extension RuuviReactorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ruuviPersistence(let error):
            return error.errorDescription
        }
    }
}
