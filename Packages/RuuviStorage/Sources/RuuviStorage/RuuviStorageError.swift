import Foundation
import RuuviPersistence

public enum RuuviStorageError: Error {
    case ruuviPersistence(RuuviPersistenceError)
}
