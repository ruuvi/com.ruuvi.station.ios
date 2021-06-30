import Foundation
import RuuviVirtual
import Localize_Swift

extension VirtualReactorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .virtualPersistence(let error):
            return error.localizedDescription
        }
    }
}

extension VirtualPersistenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .persistence(let error):
            return error.localizedDescription
        case .failedToFindVirtualTag:
            return "UnexpectedError.failedToFindVirtualTag".localized()
        }
    }
}

extension VirtualRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .virtualPersistence(let error):
            return error.localizedDescription
        }
    }
}

extension VirtualStorageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .virtualPersistence(let error):
            return error.localizedDescription
        }
    }
}

extension VirtualServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .virtualPersistence(let error):
            return error.localizedDescription
        case .ruuviCore(let error):
            return error.localizedDescription
        case .ruuviLocation(let error):
            return error.localizedDescription
        case .openWeatherMap(let error):
            return error.localizedDescription
        case .failedToReverseGeocodeCoordinate:
            return "UnexpectedError.failedToReverseGeocodeCoordinate".localized()
        case .callerDeinitedDuringOperation:
            return "UnexpectedError.callerDeinitedDuringOperation".localized()
        }
    }
}

extension OWMError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToParseOpenWeatherMapResponse:
            return "OWMError.failedToParseOpenWeatherMapResponse".localized()
        case .apiLimitExceeded:
            return "OWMError.apiLimitExceeded".localized()
        case .notAHttpResponse:
            return "OWMError.notAHttpResponse".localized()
        case .invalidApiKey:
            return "OWMError.invalidApiKey".localized()
        case .networking(let error):
            return error.localizedDescription
        case .missingOpenWeatherMapAPIKey:
            return "ExpectedError.missingOpenWeatherMapAPIKey".localized()
        }
    }
}
