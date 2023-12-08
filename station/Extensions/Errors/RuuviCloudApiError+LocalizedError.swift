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
            return "Gateway not found" // TODO: @rinat localize
        case .erGatewayAlreadyWhitelisted:
            return "Gateway already whitelisted" // TODO: @rinat localize
        case .erGatewayStatusReportFailed:
            return "Gateway status report failed" // TODO: @rinat localize
        case .erConflict:
            return "Conflict" // TODO: @rinat localize
        case .erSubscriptionNotFound:
            return RuuviLocalization.UserApiError.erSubscriptionNotFound
        case .erShareCountReached:
            return RuuviLocalization.UserApiError.erShareCountReached
        case .erClaimCountReached:
            return "Maximum claim count for the user reached" // TODO: @rinat localize
        case .erSensorShareCountReached:
            return "Maximum share count for the sensor reached" // TODO: @rinat localize
        case .erNoDataToShare:
            return "No data to share" // TODO: @rinat localize
        case .erSensorAlreadyShared:
            return RuuviLocalization.UserApiError.erSensorAlreadyShared
        case .erSensorAlreadyClaimed:
            return RuuviLocalization.UserApiError.erSensorAlreadyClaimed("") // TODO: @rinat check
        case .erSensorAlreadyRegistered:
            return "Sensor already registered" // TODO: @rinat localize
        case .erUnableToSendEmail:
            return RuuviLocalization.UserApiError.erUnableToSendEmail
        case .erSubscriptionCodeExists:
            return "Subscription code exists" // TODO: @rinat localize
        case .erSubscriptionCodeUsed:
            return "Subscription code used" // TODO: @rinat localize
        case .erMissingArgument:
            return RuuviLocalization.UserApiError.erMissingArgument
        case .erInvalidDensityMode:
            return RuuviLocalization.UserApiError.erInvalidDensityMode
        case .erInvalidSortMode:
            return RuuviLocalization.UserApiError.erInvalidSortMode
        case .erInvalidTimeRange:
            return RuuviLocalization.UserApiError.erInvalidTimeRange
        case .erOldEntry:
            return "Old entry" // TODO: @rinat localize
        case .erInvalidEmailAddress:
            return RuuviLocalization.UserApiError.erInvalidEmailAddress
        case .erInvalidMacAddress:
            return RuuviLocalization.UserApiError.erInvalidMacAddress
        case .erInvalidEnumValue:
            return "Invalid enum value" // TODO: @rinat localize
        case .erSubDataStorageError:
            return RuuviLocalization.UserApiError.erSubDataStorageError
        case .erSubNoUser:
            return RuuviLocalization.UserApiError.erSubNoUser
        case .ok:
            return "Ok" // TODO: @rinat localize
        }
    }
}
