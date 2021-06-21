import Foundation

public enum RuuviLocationError: Error {
    case map(Error)
    case callbackErrorAndResultAreNil
}
