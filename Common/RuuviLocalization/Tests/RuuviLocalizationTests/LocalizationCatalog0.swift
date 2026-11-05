import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog0: [LocalizedStringContract] = [
        .init(
            key: "abs_humidity", arguments: [],
            defaultValue: { RuuviLocalization.absHumidity },
            localized: { RuuviLocalization.absHumidity($0) }),
        .init(
            key: "absolute_humidity", arguments: [],
            defaultValue: { RuuviLocalization.absoluteHumidity },
            localized: { RuuviLocalization.absoluteHumidity($0) }),
        .init(
            key: "acc_x", arguments: [],
            defaultValue: { RuuviLocalization.accX },
            localized: { RuuviLocalization.accX($0) }),
        .init(
            key: "acc_y", arguments: [],
            defaultValue: { RuuviLocalization.accY },
            localized: { RuuviLocalization.accY($0) }),
        .init(
            key: "acc_z", arguments: [],
            defaultValue: { RuuviLocalization.accZ },
            localized: { RuuviLocalization.accZ($0) }),
        .init(
            key: "acceleration", arguments: [],
            defaultValue: { RuuviLocalization.acceleration },
            localized: { RuuviLocalization.acceleration($0) }),
        .init(
            key: "activity_failed_generic", arguments: [],
            defaultValue: { RuuviLocalization.activityFailedGeneric },
            localized: { RuuviLocalization.activityFailedGeneric($0) }),
        .init(
            key: "activity_ongoing_generic", arguments: [],
            defaultValue: { RuuviLocalization.activityOngoingGeneric },
            localized: { RuuviLocalization.activityOngoingGeneric($0) }),
        .init(
            key: "activity_saving_fail", arguments: [],
            defaultValue: { RuuviLocalization.activitySavingFail },
            localized: { RuuviLocalization.activitySavingFail($0) }),
        .init(
            key: "activity_saving_success", arguments: [],
            defaultValue: { RuuviLocalization.activitySavingSuccess },
            localized: { RuuviLocalization.activitySavingSuccess($0) }),
        .init(
            key: "activity_saving_to_cloud", arguments: [],
            defaultValue: { RuuviLocalization.activitySavingToCloud },
            localized: { RuuviLocalization.activitySavingToCloud($0) }),
        .init(
            key: "activity_success_generic", arguments: [],
            defaultValue: { RuuviLocalization.activitySuccessGeneric },
            localized: { RuuviLocalization.activitySuccessGeneric($0) }),
        .init(
            key: "add_a_sensor", arguments: [],
            defaultValue: { RuuviLocalization.addASensor },
            localized: { RuuviLocalization.addASensor($0) }),
        .init(
            key: "add_sensor", arguments: [],
            defaultValue: { RuuviLocalization.addSensor },
            localized: { RuuviLocalization.addSensor($0) }),
        .init(
            key: "add_sensor_description", arguments: [],
            defaultValue: { RuuviLocalization.addSensorDescription },
            localized: { RuuviLocalization.addSensorDescription($0) }),
        .init(
            key: "add_sensor_nfc_df3_error", arguments: [],
            defaultValue: { RuuviLocalization.addSensorNfcDf3Error },
            localized: { RuuviLocalization.addSensorNfcDf3Error($0) }),
        .init(
            key: "add_sensor_via_nfc", arguments: [],
            defaultValue: { RuuviLocalization.addSensorViaNfc },
            localized: { RuuviLocalization.addSensorViaNfc($0) }),
        .init(
            key: "add_with_nfc", arguments: [],
            defaultValue: { RuuviLocalization.addWithNfc },
            localized: { RuuviLocalization.addWithNfc($0) }),
        .init(
            key: "ago", arguments: [],
            defaultValue: { RuuviLocalization.ago },
            localized: { RuuviLocalization.ago($0) }),
        .init(
            key: "air_pressure", arguments: [],
            defaultValue: { RuuviLocalization.airPressure },
            localized: { RuuviLocalization.airPressure($0) }),
        .init(
            key: "air_quality", arguments: [],
            defaultValue: { RuuviLocalization.airQuality },
            localized: { RuuviLocalization.airQuality($0) }),
        .init(
            key: "alert_cloud_connection_delay_summary", arguments: [1234],
            defaultValue: { RuuviLocalization.alertCloudConnectionDelaySummary(1234) },
            localized: { RuuviLocalization.alertCloudConnectionDelaySummary(1234, $0) }),
        .init(
            key: "alert_cloud_connection_description", arguments: [1234],
            defaultValue: { RuuviLocalization.alertCloudConnectionDescription(1234) },
            localized: { RuuviLocalization.alertCloudConnectionDescription(1234, $0) }),
        .init(
            key: "alert_cloud_connection_dialog_description", arguments: [],
            defaultValue: { RuuviLocalization.alertCloudConnectionDialogDescription },
            localized: { RuuviLocalization.alertCloudConnectionDialogDescription($0) }),
        .init(
            key: "alert_cloud_connection_dialog_title", arguments: [],
            defaultValue: { RuuviLocalization.alertCloudConnectionDialogTitle },
            localized: { RuuviLocalization.alertCloudConnectionDialogTitle($0) }),
        .init(
            key: "alert_cloud_connection_title", arguments: [],
            defaultValue: { RuuviLocalization.alertCloudConnectionTitle },
            localized: { RuuviLocalization.alertCloudConnectionTitle($0) }),
        .init(
            key: "alert_connection", arguments: [],
            defaultValue: { RuuviLocalization.alertConnection },
            localized: { RuuviLocalization.alertConnection($0) }),
        .init(
            key: "alert_movement", arguments: [],
            defaultValue: { RuuviLocalization.alertMovement },
            localized: { RuuviLocalization.alertMovement($0) }),
        .init(
            key: "alert_notification_absolute_humidity_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationAbsoluteHumidityHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationAbsoluteHumidityHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_absolute_humidity_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationAbsoluteHumidityLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationAbsoluteHumidityLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_aqi_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationAqiHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationAqiHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_aqi_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationAqiLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationAqiLowThreshold("Sensor 1 🌡️", $0) }),
    ]
}
