import Foundation
import RuuviVirtual
import RuuviStorage
import RuuviReactor
import RuuviPool
import RuuviPersistence
import RuuviDaemon
import BTKit

extension RuuviDaemonError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .btkit(let error):
            return error.errorDescription
        case .ruuviPersistence(let error):
            return error.errorDescription
        case .ruuviPool(let error):
            return error.errorDescription
        case .ruuviReactor(let error):
            return error.errorDescription
        case .ruuviStorage(let error):
            return error.errorDescription
        case .virtualStorage(let error):
            return error.errorDescription
        }
    }
}
