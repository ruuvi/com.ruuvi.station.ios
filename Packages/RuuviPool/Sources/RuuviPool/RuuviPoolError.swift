import Foundation
import RuuviPersistence

public enum RuuviPoolError: Error {
    case ruuviPersistence(RuuviPersistenceError)
}
