import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog5: [LocalizedStringContract] = [
        .init(
            key: "copy_unique_id", arguments: [],
            defaultValue: { RuuviLocalization.copyUniqueId },
            localized: { RuuviLocalization.copyUniqueId($0) }),
        .init(
            key: "customisation_settings", arguments: [],
            defaultValue: { RuuviLocalization.customisationSettings },
            localized: { RuuviLocalization.customisationSettings($0) }),
        .init(
            key: "customisation_settings_description", arguments: [],
            defaultValue: { RuuviLocalization.customisationSettingsDescription },
            localized: { RuuviLocalization.customisationSettingsDescription($0) }),
        .init(
            key: "dark_theme", arguments: [],
            defaultValue: { RuuviLocalization.darkTheme },
            localized: { RuuviLocalization.darkTheme($0) }),
        .init(
            key: "dashboard_banner_signed_out", arguments: [],
            defaultValue: { RuuviLocalization.dashboardBannerSignedOut },
            localized: { RuuviLocalization.dashboardBannerSignedOut($0) }),
        .init(
            key: "dashboard_no_sensors_message", arguments: [],
            defaultValue: { RuuviLocalization.dashboardNoSensorsMessage },
            localized: { RuuviLocalization.dashboardNoSensorsMessage($0) }),
        .init(
            key: "dashboard_no_sensors_message_signed_out", arguments: [],
            defaultValue: { RuuviLocalization.dashboardNoSensorsMessageSignedOut },
            localized: { RuuviLocalization.dashboardNoSensorsMessageSignedOut($0) }),
        .init(
            key: "day_1", arguments: [],
            defaultValue: { RuuviLocalization.day1 },
            localized: { RuuviLocalization.day1($0) }),
        .init(
            key: "day_10", arguments: [],
            defaultValue: { RuuviLocalization.day10 },
            localized: { RuuviLocalization.day10($0) }),
        .init(
            key: "day_2", arguments: [],
            defaultValue: { RuuviLocalization.day2 },
            localized: { RuuviLocalization.day2($0) }),
        .init(
            key: "day_3", arguments: [],
            defaultValue: { RuuviLocalization.day3 },
            localized: { RuuviLocalization.day3($0) }),
        .init(
            key: "day_4", arguments: [],
            defaultValue: { RuuviLocalization.day4 },
            localized: { RuuviLocalization.day4($0) }),
        .init(
            key: "day_5", arguments: [],
            defaultValue: { RuuviLocalization.day5 },
            localized: { RuuviLocalization.day5($0) }),
        .init(
            key: "day_6", arguments: [],
            defaultValue: { RuuviLocalization.day6 },
            localized: { RuuviLocalization.day6($0) }),
        .init(
            key: "day_7", arguments: [],
            defaultValue: { RuuviLocalization.day7 },
            localized: { RuuviLocalization.day7($0) }),
        .init(
            key: "day_8", arguments: [],
            defaultValue: { RuuviLocalization.day8 },
            localized: { RuuviLocalization.day8($0) }),
        .init(
            key: "day_9", arguments: [],
            defaultValue: { RuuviLocalization.day9 },
            localized: { RuuviLocalization.day9($0) }),
        .init(
            key: "day_x", arguments: [Float(13.25)],
            defaultValue: { RuuviLocalization.dayX(Float(13.25)) },
            localized: { RuuviLocalization.dayX(Float(13.25), $0) }),
        .init(
            key: "dBm", arguments: [],
            defaultValue: { RuuviLocalization.dBm },
            localized: { RuuviLocalization.dBm($0) }),
        .init(
            key: "decrease_graph_size", arguments: [],
            defaultValue: { RuuviLocalization.decreaseGraphSize },
            localized: { RuuviLocalization.decreaseGraphSize($0) }),
        .init(
            key: "description_text_acceleration", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextAcceleration },
            localized: { RuuviLocalization.descriptionTextAcceleration($0) }),
        .init(
            key: "description_text_air_quality", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextAirQuality },
            localized: { RuuviLocalization.descriptionTextAirQuality($0) }),
        .init(
            key: "description_text_battery_voltage", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextBatteryVoltage },
            localized: { RuuviLocalization.descriptionTextBatteryVoltage($0) }),
        .init(
            key: "description_text_co2", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextCo2 },
            localized: { RuuviLocalization.descriptionTextCo2($0) }),
        .init(
            key: "description_text_humidity_absolute", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextHumidityAbsolute },
            localized: { RuuviLocalization.descriptionTextHumidityAbsolute($0) }),
        .init(
            key: "description_text_humidity_dewpoint", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextHumidityDewpoint },
            localized: { RuuviLocalization.descriptionTextHumidityDewpoint($0) }),
        .init(
            key: "description_text_humidity_relative", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextHumidityRelative },
            localized: { RuuviLocalization.descriptionTextHumidityRelative($0) }),
        .init(
            key: "description_text_luminosity", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextLuminosity },
            localized: { RuuviLocalization.descriptionTextLuminosity($0) }),
        .init(
            key: "description_text_measurement_sequence_number", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextMeasurementSequenceNumber },
            localized: { RuuviLocalization.descriptionTextMeasurementSequenceNumber($0) }),
        .init(
            key: "description_text_movement", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextMovement },
            localized: { RuuviLocalization.descriptionTextMovement($0) }),
        .init(
            key: "description_text_nox", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextNox },
            localized: { RuuviLocalization.descriptionTextNox($0) }),
        .init(
            key: "description_text_pm", arguments: [],
            defaultValue: { RuuviLocalization.descriptionTextPm },
            localized: { RuuviLocalization.descriptionTextPm($0) }),
    ]
}
