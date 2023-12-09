import Foundation
import RuuviReactor

extension RuuviReactorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .ruuviPersistence(error):
            error.errorDescription
        }
    }
}
