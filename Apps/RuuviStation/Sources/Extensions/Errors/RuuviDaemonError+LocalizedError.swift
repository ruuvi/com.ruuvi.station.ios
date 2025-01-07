import BTKit
import Foundation
import RuuviDaemon
import RuuviPersistence
import RuuviPool
import RuuviReactor
import RuuviStorage

extension RuuviDaemonError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .btkit(error):
            error.errorDescription
        case let .ruuviPersistence(error):
            error.errorDescription
        case let .ruuviPool(error):
            error.errorDescription
        case let .ruuviReactor(error):
            error.errorDescription
        case let .ruuviStorage(error):
            error.errorDescription
        }
    }
}
