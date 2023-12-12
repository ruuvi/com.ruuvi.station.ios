import BTKit
import Foundation
import RuuviDFU
import RuuviLocal
import RuuviLocalization
import RuuviPersistence
import RuuviPool
import RuuviService
import RuuviStorage

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
        case let .ruuviLocal(error):
            error.localizedDescription
        case let .ruuviPool(error):
            error.localizedDescription
        case let .ruuviPersistence(error):
            error.localizedDescription
        case let .ruuviStorage(error):
            error.localizedDescription
        case let .ruuviService(error):
            error.localizedDescription
        case let .core(error):
            error.localizedDescription
        case let .persistence(error):
            error.localizedDescription
        case let .networking(error):
            error.localizedDescription
        case let .parse(error):
            error.localizedDescription
        case let .map(error):
            error.localizedDescription
        case let .expected(error):
            error.localizedDescription
        case let .unexpected(error):
            error.localizedDescription
        case let .btkit(error):
            error.localizedDescription
        case let .bluetooth(error):
            error.localizedDescription
        case let .writeToDisk(error):
            error.localizedDescription
        case let .dfuError(error):
            error.localizedDescription
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
            RuuviLocalization.BluetoothError.disconnected
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
            RuuviLocalization.CoreError.failedToGetDataFromResponse
        case .failedToGetCurrentLocation:
            RuuviLocalization.CoreError.failedToGetCurrentLocation
        case .failedToGetPngRepresentation:
            RuuviLocalization.CoreError.failedToGetPngRepresentation
        case .failedToGetDocumentsDirectory:
            RuuviLocalization.CoreError.failedToGetDocumentsDirectory
        case .locationPermissionDenied:
            RuuviLocalization.CoreError.locationPermissionDenied
        case .locationPermissionNotDetermined:
            RuuviLocalization.CoreError.locationPermissionNotDetermined
        case .objectNotFound:
            RuuviLocalization.CoreError.objectNotFound
        case .objectInvalidated:
            RuuviLocalization.CoreError.objectInvalidated
        case .unableToSendEmail:
            RuuviLocalization.CoreError.unableToSendEmail
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
            RuuviLocalization.ExpectedError.missingOpenWeatherMapAPIKey
        case .isAlreadySyncingLogsWithThisTag:
            RuuviLocalization.ExpectedError.isAlreadySyncingLogsWithThisTag
        case .failedToDeleteTag:
            RuuviLocalization.ExpectedError.failedToDeleteTag
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
            RuuviLocalization.UnexpectedError.callbackErrorAndResultAreNil
        case .callerDeinitedDuringOperation:
            RuuviLocalization.UnexpectedError.callerDeinitedDuringOperation
        case .failedToReverseGeocodeCoordinate:
            RuuviLocalization.UnexpectedError.failedToReverseGeocodeCoordinate
        case .failedToFindRuuviTag:
            RuuviLocalization.UnexpectedError.failedToFindRuuviTag
        case .failedToFindLogsForTheTag:
            RuuviLocalization.UnexpectedError.failedToFindLogsForTheTag
        case .viewModelUUIDIsNil:
            RuuviLocalization.UnexpectedError.viewModelUUIDIsNil
        case .attemptToReadDataFromRealmWithoutLUID:
            RuuviLocalization.UnexpectedError.attemptToReadDataFromRealmWithoutLUID
        case .failedToFindOrGenerateBackgroundImage:
            RuuviLocalization.UnexpectedError.failedToFindOrGenerateBackgroundImage
        case .bothLuidAndMacAreNil:
            RuuviLocalization.UnexpectedError.bothLuidAndMacAreNil
        }
    }
}
