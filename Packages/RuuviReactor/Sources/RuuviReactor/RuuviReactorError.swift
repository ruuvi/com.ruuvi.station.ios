import Foundation
import RuuviPersistence

public enum RuuviReactorError: Error {
    case ruuviPersistence(RuuviPersistenceError)
}
