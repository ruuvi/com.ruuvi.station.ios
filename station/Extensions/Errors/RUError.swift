import Foundation
import BTKit
import RuuviStorage
import RuuviPersistence
import RuuviPool
import RuuviLocal
import RuuviService
import RuuviDFU
import RuuviLocalization

enum RUError: Error {
    case ruuviLocal(RuuviLocalError)
    case ruuviPool(RuuviPoolError)
    case ruuviStorage(RuuviStorageError)
    case ruuviPersistence(RuuviPersistenceError)
    case ruuviService(RuuviServiceError)
    case core(CoreError)
    case persistence(Error)
    case networking(Error)
    case parse(Error)
    case map(Error)
    case bluetooth(BluetoothError)
    case btkit(BTError)
    case expected(ExpectedError)
    case unexpected(UnexpectedError)
    case writeToDisk(Error)
    case dfuError(RuuviDfuError)
}

extension RUError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ruuviLocal(let error):
            return error.localizedDescription
        case .ruuviPool(let error):
            return error.localizedDescription
        case .ruuviPersistence(let error):
            return error.localizedDescription
        case .ruuviStorage(let error):
            return error.localizedDescription
        case .ruuviService(let error):
            return error.localizedDescription
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
        case .dfuError(let error):
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
            return RuuviLocalization.BluetoothError.disconnected
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
            return RuuviLocalization.CoreError.failedToGetDataFromResponse
        case .failedToGetCurrentLocation:
            return RuuviLocalization.CoreError.failedToGetCurrentLocation
        case .failedToGetPngRepresentation:
            return RuuviLocalization.CoreError.failedToGetPngRepresentation
        case .failedToGetDocumentsDirectory:
            return RuuviLocalization.CoreError.failedToGetDocumentsDirectory
        case .locationPermissionDenied:
            return RuuviLocalization.CoreError.locationPermissionDenied
        case .locationPermissionNotDetermined:
            return RuuviLocalization.CoreError.locationPermissionNotDetermined
        case .objectNotFound:
            return RuuviLocalization.CoreError.objectNotFound
        case .objectInvalidated:
            return RuuviLocalization.CoreError.objectInvalidated
        case .unableToSendEmail:
            return RuuviLocalization.CoreError.unableToSendEmail
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
            return RuuviLocalization.ExpectedError.missingOpenWeatherMapAPIKey
        case .isAlreadySyncingLogsWithThisTag:
            return RuuviLocalization.ExpectedError.isAlreadySyncingLogsWithThisTag
        case .failedToDeleteTag:
            return RuuviLocalization.ExpectedError.failedToDeleteTag
        }
    }
}

enum UnexpectedError: Error {
    case callbackErrorAndResultAreNil
    case callerDeinitedDuringOperation
    case failedToReverseGeocodeCoordinate
    case failedToFindRuuviTag
    case failedToFindLogsForTheTag
    case viewModelUUIDIsNil
    case attemptToReadDataFromRealmWithoutLUID
    case failedToFindOrGenerateBackgroundImage
    case bothLuidAndMacAreNil
}

extension UnexpectedError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .callbackErrorAndResultAreNil:
            return RuuviLocalization.UnexpectedError.callbackErrorAndResultAreNil
        case .callerDeinitedDuringOperation:
            return RuuviLocalization.UnexpectedError.callerDeinitedDuringOperation
        case .failedToReverseGeocodeCoordinate:
            return RuuviLocalization.UnexpectedError.failedToReverseGeocodeCoordinate
        case .failedToFindRuuviTag:
            return RuuviLocalization.UnexpectedError.failedToFindRuuviTag
        case .failedToFindLogsForTheTag:
            return RuuviLocalization.UnexpectedError.failedToFindLogsForTheTag
        case .viewModelUUIDIsNil:
            return RuuviLocalization.UnexpectedError.viewModelUUIDIsNil
        case .attemptToReadDataFromRealmWithoutLUID:
            return RuuviLocalization.UnexpectedError.attemptToReadDataFromRealmWithoutLUID
        case .failedToFindOrGenerateBackgroundImage:
            return RuuviLocalization.UnexpectedError.failedToFindOrGenerateBackgroundImage
        case .bothLuidAndMacAreNil:
            return RuuviLocalization.UnexpectedError.bothLuidAndMacAreNil
        }
    }
}
