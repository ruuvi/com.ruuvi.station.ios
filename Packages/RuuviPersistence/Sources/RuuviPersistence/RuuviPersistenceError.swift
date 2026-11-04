#if SWIFT_PACKAGE
    import RuuviOntology
    import RuuviContext
#endif
import Foundation

public enum RuuviPersistenceError: Error {
    case grdb(Error)
    case failedToFindRuuviTag
}
