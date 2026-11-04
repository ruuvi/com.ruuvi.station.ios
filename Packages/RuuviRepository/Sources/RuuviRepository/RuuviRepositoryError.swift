#if SWIFT_PACKAGE
    import RuuviOntology
#endif
import Foundation
import RuuviPool
import RuuviStorage

public enum RuuviRepositoryError: Error {
    case ruuviPool(RuuviPoolError)
    case ruuviStorage(RuuviStorageError)
}
