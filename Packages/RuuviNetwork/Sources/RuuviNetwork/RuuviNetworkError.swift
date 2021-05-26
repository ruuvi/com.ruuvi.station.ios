import Foundation

public enum RuuviNetworkError: Error {
    case noSavedApiKeyValue
    case failedToLogIn
    case doesNotHaveSensors
    case noStoredData
    case tagAlreadyExists
    case notAuthorized
}
