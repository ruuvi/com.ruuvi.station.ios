import Foundation
import RuuviCore
import RuuviLocation

public enum VirtualReactorError: Error {
    case virtualPersistence(VirtualPersistenceError)
}

public enum VirtualPersistenceError: Error {
    case persistence(Error)
    case failedToFindVirtualTag
}

public enum VirtualRepositoryError: Error {
    case virtualPersistence(VirtualPersistenceError)
}

public enum VirtualStorageError: Error {
    case virtualPersistence(VirtualPersistenceError)
}

public enum VirtualServiceError: Error {
    case ruuviCore(RuuviCoreError)
    case ruuviLocation(RuuviLocationError)
    case virtualPersistence(VirtualPersistenceError)
    case openWeatherMap(OWMError)
    case failedToReverseGeocodeCoordinate
    case callerDeinitedDuringOperation
}

public enum OWMError: Error, Equatable {
    case networking(Error)
    case missingOpenWeatherMapAPIKey
    case failedToParseOpenWeatherMapResponse
    case apiLimitExceeded
    case invalidApiKey
    case notAHttpResponse

    public static func == (lhs: OWMError, rhs: OWMError) -> Bool {
        switch (lhs, rhs) {
        case (.missingOpenWeatherMapAPIKey, .missingOpenWeatherMapAPIKey):
            return true
        case (.failedToParseOpenWeatherMapResponse, .failedToParseOpenWeatherMapResponse):
            return true
        case (.apiLimitExceeded, .apiLimitExceeded):
            return true
        case (.invalidApiKey, .invalidApiKey):
            return true
        case (.notAHttpResponse, .notAHttpResponse):
            return true
        default:
            return false
        }
    }
}
