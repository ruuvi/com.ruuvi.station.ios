import Foundation
import RuuviCloud
import RuuviLocalization

extension RuuviCloudApiError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connection:
            RuuviLocalization.internetConnectionProblem
        case .emptyResponse:
            RuuviLocalization.RuuviCloudApiError.emptyResponse
        case .failedToGetDataFromResponse:
            RuuviLocalization.RuuviCloudApiError.failedToGetDataFromResponse
        case .unexpectedHTTPStatusCode:
            RuuviLocalization.RuuviCloudApiError.unexpectedHTTPStatusCode
        case .unexpectedHTTPStatusCodeShouldRetry:
            RuuviLocalization.RuuviCloudApiError.unexpectedHTTPStatusCodeShouldRetry
        case let .api(code):
            code.localizedDescription
        case let .networking(error):
            error.localizedDescription
        case let .parsing(error):
            error.localizedDescription
        case .badParameters:
            nil
        }
    }
}

private extension RuuviCloudApiErrorCode {
    var localizedDescription: String {
        switch self {
        case .erForbidden:
            RuuviLocalization.UserApiError.erForbidden
        case .erUnauthorized:
            RuuviLocalization.UserApiError.erUnauthorized
        case .erInternal:
            RuuviLocalization.UserApiError.erInternal
        case .erInvalidFormat:
            RuuviLocalization.UserApiError.erInvalidFormat
        case .erUserNotFound:
            RuuviLocalization.UserApiError.erUserNotFound
        case .erSensorNotFound:
            RuuviLocalization.UserApiError.erSensorNotFound
        case .erTokenExpired:
            RuuviLocalization.UserApiError.erTokenExpired
        case .erThrottled:
            RuuviLocalization.UserApiError.erThrottled
        case .erGatewayNotFound:
            RuuviLocalization.UserApiError.erGatewayNotFound
        case .erGatewayAlreadyWhitelisted:
            RuuviLocalization.UserApiError.erGatewayAlreadyWhitelisted
        case .erGatewayStatusReportFailed:
            RuuviLocalization.UserApiError.erGatewayStatusReportFailed
        case .erConflict:
            RuuviLocalization.UserApiError.erConflict
        case .erSubscriptionNotFound:
            RuuviLocalization.UserApiError.erSubscriptionNotFound
        case .erShareCountReached:
            RuuviLocalization.UserApiError.erShareCountReached
        case .erClaimCountReached:
            RuuviLocalization.UserApiError.erClaimCountReached
        case .erSensorShareCountReached:
            RuuviLocalization.UserApiError.erSensorShareCountReached
        case .erNoDataToShare:
            RuuviLocalization.UserApiError.erNoDataToShare
        case .erSensorAlreadyShared:
            RuuviLocalization.UserApiError.erSensorAlreadyShared
        case .erSensorAlreadyClaimed:
            RuuviLocalization.UserApiError.erSensorAlreadyClaimed("")
        case .erSensorAlreadyRegistered:
            RuuviLocalization.UserApiError.erSensorAlreadyRegistered
        case .erUnableToSendEmail:
            RuuviLocalization.UserApiError.erUnableToSendEmail
        case .erSubscriptionCodeExists:
            RuuviLocalization.UserApiError.erSubscriptionCodeExists
        case .erSubscriptionCodeUsed:
            RuuviLocalization.UserApiError.erSubscriptionCodeUsed
        case .erMissingArgument:
            RuuviLocalization.UserApiError.erMissingArgument
        case .erInvalidDensityMode:
            RuuviLocalization.UserApiError.erInvalidDensityMode
        case .erInvalidSortMode:
            RuuviLocalization.UserApiError.erInvalidSortMode
        case .erInvalidTimeRange:
            RuuviLocalization.UserApiError.erInvalidTimeRange
        case .erOldEntry:
            RuuviLocalization.UserApiError.erOldEntry
        case .erInvalidEmailAddress:
            RuuviLocalization.UserApiError.erInvalidEmailAddress
        case .erInvalidMacAddress:
            RuuviLocalization.UserApiError.erInvalidMacAddress
        case .erInvalidEnumValue:
            RuuviLocalization.UserApiError.erInvalidEnumValue
        case .erSubDataStorageError:
            RuuviLocalization.UserApiError.erSubDataStorageError
        case .erSubNoUser:
            RuuviLocalization.UserApiError.erSubNoUser
        case .ok:
            RuuviLocalization.UserApiError.ok
        }
    }
}
