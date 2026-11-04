#if SWIFT_PACKAGE
    import RuuviLocal
    import RuuviService
    import RuuviNotifier
#endif
import BTKit
import Foundation
import RuuviPersistence
import RuuviPool
import RuuviReactor
import RuuviStorage

public enum RuuviDaemonError: Error {
    case ruuviStorage(RuuviStorageError)
    case ruuviReactor(RuuviReactorError)
    case ruuviPool(RuuviPoolError)
    case ruuviPersistence(RuuviPersistenceError)
    case btkit(BTError)
}
