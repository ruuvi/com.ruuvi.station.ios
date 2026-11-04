#if SWIFT_PACKAGE
    import RuuviOntology
#endif
import Foundation
import RuuviPersistence

public enum RuuviReactorError: Error {
    case ruuviPersistence(RuuviPersistenceError)
}
