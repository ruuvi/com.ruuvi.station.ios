import Foundation

public enum RuuviCloudApiErrorCode: String, Codable {
    // User authorized but access to resource denied
    case erForbidden = "ER_FORBIDDEN"
    // Authorization is required, but user is not authorized
    case erUnauthorized = "ER_UNAUTHORIZED"
    // Internal server error indicating an unexpected / unknown error
    case erInternal = "ER_INTERNAL"
    // Invalid input format given for one or more input fields
    case erInvalidFormat = "ER_INVALID_FORMAT"
    // Target user not found (f.ex. when sharing)
    case erUserNotFound = "ER_USER_NOT_FOUND"
    // Sensor not found (or no access)
    case erSensorNotFound = "ER_SENSOR_NOT_FOUND"
    // Access token expired (f.ex. User verification tokens)
    case erTokenExpired = "ER_TOKEN_EXPIRED"
    // Throttled request due to too high call frequency
    case erThrottled = "ER_THROTTLED"
    // Gateway not found
    case erGatewayNotFound = "ER_GATEWAY_NOT_FOUND"
    // Gateway already whitelisted
    // swiftlint:disable:next inclusive_language
    case erGatewayAlreadyWhitelisted = "ER_GATEWAY_ALREADY_WHITELISTED"
    // Gateway already whitelisted
    case erGatewayStatusReportFailed = "ER_GATEWAY_STATUS_REPORT_FAILED"
    // Data already exists, cannot update
    case erConflict = "ER_CONFLICT"

    // Thrown when action requires a subscription but it is not found
    case erSubscriptionNotFound = "ER_SUBSCRIPTION_NOT_FOUND"
    // Maximum share count for the user reached
    case erShareCountReached = "ER_SHARE_COUNT_REACHED"
    // Maximum claim count for the user reached
    case erClaimCountReached = "ER_CLAIM_COUNT_REACHED"
    // Maximum share count for the sensor reached
    case erSensorShareCountReached = "ER_SENSOR_SHARE_COUNT_REACHED"
    // In order to share a sensor, it must have data - thrown when condition is not met
    case erNoDataToShare = "ER_NO_DATA_TO_SHARE"
    // The sensor has already been shared to target user
    case erSensorAlreadyShared = "ER_SENSOR_ALREADY_SHARED"
    // The sensor has already been claimed
    case erSensorAlreadyClaimed = "ER_SENSOR_ALREADY_CLAIMED"
    // The sensor has already been registered
    case erSensorAlreadyRegistered = "ER_SENSOR_ALREADY_REGISTERED"
    // Error sending an e-mail notification / verification
    case erUnableToSendEmail = "ER_UNABLE_TO_SEND_EMAIL"
    // Tried to add duplicate subscription to a code.
    case erSubscriptionCodeExists = "ER_SUBSCRIPTION_CODE_EXISTS"
    // Tried to claim already used code.
    case erSubscriptionCodeUsed = "ER_SUBSCRIPTION_CODE_USED"

    // Missing a required argument from API end-point
    case erMissingArgument = "ER_MISSING_ARGUMENT"
    // Density mode must be one of ['dense', 'sparse', 'mixed']
    case erInvalidDensityMode = "ER_INVALID_DENSITY_MODE"
    // Sort fetched data ascending on descending based on timestamp. Must be one of ['asc', 'desc']
    case erInvalidSortMode = "ER_INVALID_SORT_MODE"
    // Invalid time range given - most often since timestamp after until timestamp
    case erInvalidTimeRange = "ER_INVALID_TIME_RANGE"
    // Newer data already exists, cannot update
    case erOldEntry = "ER_OLD_ENTRY"
    // Invalid e-mail format in given argument
    case erInvalidEmailAddress = "ER_INVALID_EMAIL_ADDRESS"
    // Invalid MAC address format in given argument
    case erInvalidMacAddress = "ER_INVALID_MAC_ADDRESS"
    // Invalid ENUM value given
    case erInvalidEnumValue = "ER_INVALID_ENUM_VALUE"
    case erSubDataStorageError = "ER_SUB_DATA_STORAGE_ERROR"
    // Returned when no user could be found or created via e-mail verification flow
    case erSubNoUser = "ER_SUB_NO_USER"

    // Operation was successful
    case ok = "OK"
}
