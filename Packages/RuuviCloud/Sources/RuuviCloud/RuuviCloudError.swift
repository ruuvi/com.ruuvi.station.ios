import Foundation

public enum RuuviCloudError: Error {
    case noSavedApiKeyValue
    case failedToLogIn
    case doesNotHaveSensors
    case noStoredData
    case tagAlreadyExists
    case notAuthorized
}
