import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog1: [LocalizedStringContract] = [
        .init(
            key: "alert_notification_battery_voltage_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationBatteryVoltageHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationBatteryVoltageHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_battery_voltage_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationBatteryVoltageLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationBatteryVoltageLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_co2_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationCo2HighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationCo2HighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_co2_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationCo2LowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationCo2LowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_dew_point_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationDewPointHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationDewPointHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_dew_point_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationDewPointLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationDewPointLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_humidity_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationHumidityHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationHumidityHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_humidity_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationHumidityLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationHumidityLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_luminosity_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationLuminosityHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationLuminosityHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_luminosity_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationLuminosityLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationLuminosityLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_nox_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationNoxHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationNoxHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_nox_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationNoxLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationNoxLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_offline_message", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationOfflineMessage("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationOfflineMessage("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_pm10_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationPm10HighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationPm10HighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_pm10_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationPm10LowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationPm10LowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_pm1_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationPm1HighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationPm1HighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_pm1_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationPm1LowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationPm1LowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_pm25_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationPm25HighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationPm25HighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_pm25_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationPm25LowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationPm25LowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_pm4_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationPm4HighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationPm4HighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_pm4_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationPm4LowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationPm4LowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_pressure_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationPressureHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationPressureHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_pressure_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationPressureLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationPressureLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_rssi_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationRssiHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationRssiHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_rssi_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationRssiLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationRssiLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_sound_average_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationSoundAverageHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationSoundAverageHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_sound_average_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationSoundAverageLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationSoundAverageLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_sound_instant_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationSoundInstantHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationSoundInstantHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_sound_instant_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationSoundInstantLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationSoundInstantLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_sound_peak_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationSoundPeakHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationSoundPeakHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_sound_peak_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationSoundPeakLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationSoundPeakLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_temperature_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationTemperatureHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationTemperatureHighThreshold("Sensor 1 🌡️", $0) }),
    ]
}
