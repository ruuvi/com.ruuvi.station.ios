import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog23: [LocalizedStringContract] = [
        .init(
            key: "UnexpectedError.failedToReverseGeocodeCoordinate", arguments: [],
            defaultValue: { RuuviLocalization.UnexpectedError.failedToReverseGeocodeCoordinate },
            localized: { RuuviLocalization.UnexpectedError.failedToReverseGeocodeCoordinate($0) }),
        .init(
            key: "UnexpectedError.viewModelUUIDIsNil", arguments: [],
            defaultValue: { RuuviLocalization.UnexpectedError.viewModelUUIDIsNil },
            localized: { RuuviLocalization.UnexpectedError.viewModelUUIDIsNil($0) }),
        .init(
            key: "UnitPressure.Pascal.title", arguments: [],
            defaultValue: { RuuviLocalization.UnitPressure.Pascal.title },
            localized: { RuuviLocalization.UnitPressure.Pascal.title($0) }),
        .init(
            key: "UnitPressure.hectopascal.title", arguments: [],
            defaultValue: { RuuviLocalization.UnitPressure.Hectopascal.title },
            localized: { RuuviLocalization.UnitPressure.Hectopascal.title($0) }),
        .init(
            key: "UnitPressure.inchOfMercury.title", arguments: [],
            defaultValue: { RuuviLocalization.UnitPressure.InchOfMercury.title },
            localized: { RuuviLocalization.UnitPressure.InchOfMercury.title($0) }),
        .init(
            key: "UnitPressure.millimetreOfMercury.title", arguments: [],
            defaultValue: { RuuviLocalization.UnitPressure.MillimetreOfMercury.title },
            localized: { RuuviLocalization.UnitPressure.MillimetreOfMercury.title($0) }),
        .init(
            key: "UserApiError.ER_CLAIM_COUNT_REACHED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erClaimCountReached },
            localized: { RuuviLocalization.UserApiError.erClaimCountReached($0) }),
        .init(
            key: "UserApiError.ER_CONFLICT", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erConflict },
            localized: { RuuviLocalization.UserApiError.erConflict($0) }),
        .init(
            key: "UserApiError.ER_FORBIDDEN", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erForbidden },
            localized: { RuuviLocalization.UserApiError.erForbidden($0) }),
        .init(
            key: "UserApiError.ER_GATEWAY_ALREADY_WHITELISTED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erGatewayAlreadyWhitelisted },
            localized: { RuuviLocalization.UserApiError.erGatewayAlreadyWhitelisted($0) }),
        .init(
            key: "UserApiError.ER_GATEWAY_NOT_FOUND", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erGatewayNotFound },
            localized: { RuuviLocalization.UserApiError.erGatewayNotFound($0) }),
        .init(
            key: "UserApiError.ER_GATEWAY_STATUS_REPORT_FAILED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erGatewayStatusReportFailed },
            localized: { RuuviLocalization.UserApiError.erGatewayStatusReportFailed($0) }),
        .init(
            key: "UserApiError.ER_INTERNAL", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erInternal },
            localized: { RuuviLocalization.UserApiError.erInternal($0) }),
        .init(
            key: "UserApiError.ER_INVALID_DENSITY_MODE", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erInvalidDensityMode },
            localized: { RuuviLocalization.UserApiError.erInvalidDensityMode($0) }),
        .init(
            key: "UserApiError.ER_INVALID_EMAIL_ADDRESS", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erInvalidEmailAddress },
            localized: { RuuviLocalization.UserApiError.erInvalidEmailAddress($0) }),
        .init(
            key: "UserApiError.ER_INVALID_ENUM_VALUE", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erInvalidEnumValue },
            localized: { RuuviLocalization.UserApiError.erInvalidEnumValue($0) }),
        .init(
            key: "UserApiError.ER_INVALID_FORMAT", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erInvalidFormat },
            localized: { RuuviLocalization.UserApiError.erInvalidFormat($0) }),
        .init(
            key: "UserApiError.ER_INVALID_MAC_ADDRESS", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erInvalidMacAddress },
            localized: { RuuviLocalization.UserApiError.erInvalidMacAddress($0) }),
        .init(
            key: "UserApiError.ER_INVALID_SORT_MODE", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erInvalidSortMode },
            localized: { RuuviLocalization.UserApiError.erInvalidSortMode($0) }),
        .init(
            key: "UserApiError.ER_INVALID_TIME_RANGE", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erInvalidTimeRange },
            localized: { RuuviLocalization.UserApiError.erInvalidTimeRange($0) }),
        .init(
            key: "UserApiError.ER_MISSING_ARGUMENT", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erMissingArgument },
            localized: { RuuviLocalization.UserApiError.erMissingArgument($0) }),
        .init(
            key: "UserApiError.ER_NO_DATA_TO_SHARE", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erNoDataToShare },
            localized: { RuuviLocalization.UserApiError.erNoDataToShare($0) }),
        .init(
            key: "UserApiError.ER_OLD_ENTRY", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erOldEntry },
            localized: { RuuviLocalization.UserApiError.erOldEntry($0) }),
        .init(
            key: "UserApiError.ER_SENSOR_ALREADY_CLAIMED", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.UserApiError.erSensorAlreadyClaimed("Sensor 1 🌡️") },
            localized: { RuuviLocalization.UserApiError.erSensorAlreadyClaimed("Sensor 1 🌡️", $0) }),
        .init(
            key: "UserApiError.ER_SENSOR_ALREADY_CLAIMED_NO_EMAIL", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erSensorAlreadyClaimedNoEmail },
            localized: { RuuviLocalization.UserApiError.erSensorAlreadyClaimedNoEmail($0) }),
        .init(
            key: "UserApiError.ER_SENSOR_ALREADY_REGISTERED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erSensorAlreadyRegistered },
            localized: { RuuviLocalization.UserApiError.erSensorAlreadyRegistered($0) }),
        .init(
            key: "UserApiError.ER_SENSOR_ALREADY_SHARED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erSensorAlreadyShared },
            localized: { RuuviLocalization.UserApiError.erSensorAlreadyShared($0) }),
        .init(
            key: "UserApiError.ER_SENSOR_NOT_FOUND", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erSensorNotFound },
            localized: { RuuviLocalization.UserApiError.erSensorNotFound($0) }),
        .init(
            key: "UserApiError.ER_SENSOR_SHARE_COUNT_REACHED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erSensorShareCountReached },
            localized: { RuuviLocalization.UserApiError.erSensorShareCountReached($0) }),
        .init(
            key: "UserApiError.ER_SHARE_COUNT_REACHED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erShareCountReached },
            localized: { RuuviLocalization.UserApiError.erShareCountReached($0) }),
        .init(
            key: "UserApiError.ER_SUB_DATA_STORAGE_ERROR", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erSubDataStorageError },
            localized: { RuuviLocalization.UserApiError.erSubDataStorageError($0) }),
        .init(
            key: "UserApiError.ER_SUB_NO_USER", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erSubNoUser },
            localized: { RuuviLocalization.UserApiError.erSubNoUser($0) }),
    ]
}
