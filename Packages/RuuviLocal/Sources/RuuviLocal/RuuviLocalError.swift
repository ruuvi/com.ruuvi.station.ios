#if SWIFT_PACKAGE
    import RuuviOntology
#endif
import Foundation

public enum RuuviLocalError: Error {
    case disk(Error)
    case failedToGetJpegRepresentation
    case failedToGetDocumentsDirectory
}
