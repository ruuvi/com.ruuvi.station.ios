import Foundation
import RuuviCloud
import RuuviLocalization

extension RuuviCloudApiError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connection:
            return RuuviLocalization.internetConnectionProblem
        case .emptyResponse:
            return RuuviLocalization.RuuviCloudApiError.emptyResponse
        case .failedToGetDataFromResponse:
            return RuuviLocalization.RuuviCloudApiError.failedToGetDataFromResponse
        case .unexpectedHTTPStatusCode:
            return RuuviLocalization.RuuviCloudApiError.unexpectedHTTPStatusCode
        case .api(let code):
            return code.localizedDescription
        case .networking(let error):
            return error.localizedDescription
        case .parsing(let error):
            return error.localizedDescription
        case .unauthorized:
            return nil
        }
    }
}

private extension RuuviCloudApiErrorCode {
    var localizedDescription: String {
        switch self {
        case .erForbidden:
            return RuuviLocalization.UserApiError.erForbidden
        case .erUnauthorized:
            return RuuviLocalization.UserApiError.erUnauthorized
        case .erInternal:
            return RuuviLocalization.UserApiError.erInternal
        case .erInvalidFormat:
            return RuuviLocalization.UserApiError.erInvalidFormat
        case .erUserNotFound:
            return RuuviLocalization.UserApiError.erUserNotFound
        case .erSensorNotFound:
            return RuuviLocalization.UserApiError.erSensorNotFound
        case .erTokenExpired:
            return RuuviLocalization.UserApiError.erTokenExpired
        case .erThrottled:
            return RuuviLocalization.UserApiError.erThrottled
        case .erGatewayNotFound:
            return RuuviLocalization.UserApiError.erGatewayNotFound
        case .erGatewayAlreadyWhitelisted:
            return RuuviLocalization.UserApiError.erGatewayAlreadyWhitelisted
        case .erGatewayStatusReportFailed:
            return RuuviLocalization.UserApiError.erGatewayStatusReportFailed
        case .erConflict:
            return RuuviLocalization.UserApiError.erConflict
        case .erSubscriptionNotFound:
            return RuuviLocalization.UserApiError.erSubscriptionNotFound
        case .erShareCountReached:
            return RuuviLocalization.UserApiError.erShareCountReached
        case .erClaimCountReached:
            return RuuviLocalization.UserApiError.erClaimCountReached
        case .erSensorShareCountReached:
            return RuuviLocalization.UserApiError.erSensorShareCountReached
        case .erNoDataToShare:
            return RuuviLocalization.UserApiError.erNoDataToShare
        case .erSensorAlreadyShared:
            return RuuviLocalization.UserApiError.erSensorAlreadyShared
        case .erSensorAlreadyClaimed:
            return RuuviLocalization.UserApiError.erSensorAlreadyClaimed("")
        case .erSensorAlreadyRegistered:
            return RuuviLocalization.UserApiError.erSensorAlreadyRegistered
        case .erUnableToSendEmail:
            return RuuviLocalization.UserApiError.erUnableToSendEmail
        case .erSubscriptionCodeExists:
            return RuuviLocalization.UserApiError.erSubscriptionCodeExists
        case .erSubscriptionCodeUsed:
            return RuuviLocalization.UserApiError.erSubscriptionCodeUsed
        case .erMissingArgument:
            return RuuviLocalization.UserApiError.erMissingArgument
        case .erInvalidDensityMode:
            return RuuviLocalization.UserApiError.erInvalidDensityMode
        case .erInvalidSortMode:
            return RuuviLocalization.UserApiError.erInvalidSortMode
        case .erInvalidTimeRange:
            return RuuviLocalization.UserApiError.erInvalidTimeRange
        case .erOldEntry:
            return RuuviLocalization.UserApiError.erOldEntry
        case .erInvalidEmailAddress:
            return RuuviLocalization.UserApiError.erInvalidEmailAddress
        case .erInvalidMacAddress:
            return RuuviLocalization.UserApiError.erInvalidMacAddress
        case .erInvalidEnumValue:
            return RuuviLocalization.UserApiError.erInvalidEnumValue
        case .erSubDataStorageError:
            return RuuviLocalization.UserApiError.erSubDataStorageError
        case .erSubNoUser:
            return RuuviLocalization.UserApiError.erSubNoUser
        case .ok:
            return RuuviLocalization.UserApiError.ok
        }
    }
}
