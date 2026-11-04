#if SWIFT_PACKAGE
    import RuuviOntology
#endif
import Foundation
import RuuviPersistence

public enum RuuviStorageError: Error {
    case ruuviPersistence(RuuviPersistenceError)
}
