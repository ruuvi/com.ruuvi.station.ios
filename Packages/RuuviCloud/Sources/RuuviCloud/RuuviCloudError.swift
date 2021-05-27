import Foundation

public enum RuuviCloudError: Error {
    case api(Error)
    case noSavedApiKeyValue
    case failedToLogIn
    case doesNotHaveSensors
    case noStoredData
    case tagAlreadyExists
    case notAuthorized
}
