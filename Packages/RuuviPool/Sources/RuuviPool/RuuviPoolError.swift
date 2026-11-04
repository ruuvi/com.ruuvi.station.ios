#if SWIFT_PACKAGE
    import RuuviOntology
    import RuuviLocal
#endif
import Foundation
import RuuviPersistence

public enum RuuviPoolError: Error {
    case ruuviPersistence(RuuviPersistenceError)
}
