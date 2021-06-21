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

public enum OWMError: Error {
    case networking(Error)
    case missingOpenWeatherMapAPIKey
    case failedToParseOpenWeatherMapResponse
    case apiLimitExceeded
    case invalidApiKey
    case notAHttpResponse
}
