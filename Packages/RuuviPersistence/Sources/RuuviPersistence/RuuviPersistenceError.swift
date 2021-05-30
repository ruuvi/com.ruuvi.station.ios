import Foundation

public enum RuuviPersistenceError: Error {
    case grdb(Error)
    case realm(Error)
    case failedToFindRuuviTag
}
