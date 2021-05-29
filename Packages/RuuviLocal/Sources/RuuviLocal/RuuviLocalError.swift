import Foundation

public enum RuuviLocalError: Error {
    case disk(Error)
    case failedToGetJpegRepresentation
    case failedToGetDocumentsDirectory
}
