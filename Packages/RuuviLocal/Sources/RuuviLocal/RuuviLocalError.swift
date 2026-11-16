import Foundation

public enum RuuviLocalError: Error {
    case backgroundSuperseded
    case disk(Error)
    case failedToGetJpegRepresentation
    case failedToGetDocumentsDirectory
}
