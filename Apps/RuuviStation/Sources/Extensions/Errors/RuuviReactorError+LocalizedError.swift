import Foundation
import RuuviReactor

extension RuuviReactorError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .ruuviPersistence(error):
            error.errorDescription
        }
    }
}
