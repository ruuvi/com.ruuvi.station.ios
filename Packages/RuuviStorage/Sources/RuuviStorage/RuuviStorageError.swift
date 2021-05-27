import Foundation

public enum RuuviStorageError: Error {
    case grdb(Error)
    case realm(Error)
    case failedToFindRuuviTag
}
