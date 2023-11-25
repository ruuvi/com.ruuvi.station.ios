import Foundation
import RuuviStorage
import RuuviReactor
import RuuviPool
import RuuviPersistence
import BTKit

public enum RuuviDaemonError: Error {
    case ruuviStorage(RuuviStorageError)
    case ruuviReactor(RuuviReactorError)
    case ruuviPool(RuuviPoolError)
    case ruuviPersistence(RuuviPersistenceError)
    case btkit(BTError)
}
