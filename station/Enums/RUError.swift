import Foundation
import BTKit

enum RUError: Error {
    case core(CoreError)
    case persistence(Error)
    case networking(Error)
    case parse(Error)
    case map(Error)
    case bluetooth(BluetoothError)
    case btkit(BTError)
    case ruuviNetwork(RuuviNetworkError)
    case expected(ExpectedError)
    case unexpected(UnexpectedError)
    case writeToDisk(Error)
}

extension RUError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .core(let error):
            return error.localizedDescription
        case .persistence(let error):
            return error.localizedDescription
        case .networking(let error):
            return error.localizedDescription
        case .parse(let error):
            return error.localizedDescription
        case .map(let error):
            return error.localizedDescription
        case .expected(let error):
            return error.localizedDescription
        case .unexpected(let error):
            return error.localizedDescription
        case .btkit(let error):
            return error.localizedDescription
        case .bluetooth(let error):
            return error.localizedDescription
        case .writeToDisk(let error):
            return error.localizedDescription
        case .ruuviNetwork(let error):
            return error.localizedDescription
        }
    }
}

enum BluetoothError: Error {
    case disconnected
}

extension BluetoothError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .disconnected:
            return "BluetoothError.disconnected".localized()
        }
    }
}

enum CoreError: Error {
    case failedToGetDocumentsDirectory
    case failedToGetPngRepresentation
    case failedToGetCurrentLocation
    case failedToGetDataFromResponse
    case locationPermissionDenied
    case locationPermissionNotDetermined
    case objectNotFound
    case objectInvalidated
    case unableToSendEmail
}

extension CoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToGetDataFromResponse:
            return "CoreError.failedToGetDataFromResponse".localized()
        case .failedToGetCurrentLocation:
            return "CoreError.failedToGetCurrentLocation".localized()
        case .failedToGetPngRepresentation:
            return "CoreError.failedToGetPngRepresentation".localized()
        case .failedToGetDocumentsDirectory:
            return "CoreError.failedToGetDocumentsDirectory".localized()
        case .locationPermissionDenied:
            return "CoreError.locationPermissionDenied".localized()
        case .locationPermissionNotDetermined:
            return "CoreError.locationPermissionNotDetermined".localized()
        case .objectNotFound:
            return "CoreError.objectNotFound".localized()
        case .objectInvalidated:
            return "CoreError.objectInvalidated".localized()
        case .unableToSendEmail:
            return "CoreError.unableToSendEmail".localized()
        }
    }
}

enum ExpectedError: Error {
    case missingOpenWeatherMapAPIKey
    case isAlreadySyncingLogsWithThisTag
    case failedToDeleteTag
}

extension ExpectedError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingOpenWeatherMapAPIKey:
            return "ExpectedError.missingOpenWeatherMapAPIKey".localized()
        case .isAlreadySyncingLogsWithThisTag:
            return "ExpectedError.isAlreadySyncingLogsWithThisTag".localized()
        case .failedToDeleteTag:
            return "ExpectedError.failedToDeleteTag".localized()
        }
    }
}

enum UnexpectedError: Error {
    case callbackErrorAndResultAreNil
    case callerDeinitedDuringOperation
    case failedToReverseGeocodeCoordinate
    case failedToFindRuuviTag
    case failedToFindVirtualTag
    case failedToFindLogsForTheTag
    case viewModelUUIDIsNil
    case attemptToReadDataFromRealmWithoutLUID
    case failedToConstructURL
    case notAHttpResponse
    case failedToParseHttpResponse
}

extension UnexpectedError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .callbackErrorAndResultAreNil:
            return "UnexpectedError.callbackErrorAndResultAreNil".localized()
        case .callerDeinitedDuringOperation:
            return "UnexpectedError.callerDeinitedDuringOperation".localized()
        case .failedToReverseGeocodeCoordinate:
            return "UnexpectedError.failedToReverseGeocodeCoordinate".localized()
        case .failedToFindRuuviTag:
            return "UnexpectedError.failedToFindRuuviTag".localized()
        case .failedToFindLogsForTheTag:
            return "UnexpectedError.failedToFindLogsForTheTag".localized()
        case .viewModelUUIDIsNil:
            return "UnexpectedError.viewModelUUIDIsNil".localized()
        case .attemptToReadDataFromRealmWithoutLUID:
            return "UnexpectedError.attemptToReadDataFromRealmWithoutLUID".localized()
        case .failedToFindVirtualTag:
            return "UnexpectedError.failedToFindVirtualTag".localized()
        case .failedToConstructURL:
            return "UnexpectedError.failedToConstructURL".localized()
        case .notAHttpResponse:
            return "UnexpectedError.notAHttpResponse".localized()
        case .failedToParseHttpResponse:
            return "UnexpectedError.failedToParseHttpResponse".localized()
        }
    }
}
enum RuuviNetworkError: Error {
    case noSavedApiKeyValue
    case failedToLogIn
    case doesNotHaveSensors
    case noStoredData
    case tagAlreadyExists
}
extension RuuviNetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noSavedApiKeyValue:
            return "RuuviNetworkError.NoSavedApiKeyValue".localized()
        case .failedToLogIn:
            return "RuuviNetworkError.FailedToLogIn".localized()
        case .doesNotHaveSensors:
            return "RuuviNetworkError.DoesNotHaveSensors".localized()
        case .noStoredData:
            return "RuuviNetworkError.NoStoredData".localized()
        case .tagAlreadyExists:
            return "RuuviNetworkError.TagAlreadyExists".localized()
        }
    }
}
