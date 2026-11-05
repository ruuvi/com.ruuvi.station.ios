import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog12: [LocalizedStringContract] = [
        .init(
            key: "signal_strength", arguments: [],
            defaultValue: { RuuviLocalization.signalStrength },
            localized: { RuuviLocalization.signalStrength($0) }),
        .init(
            key: "signal_strength_dbm", arguments: [],
            defaultValue: { RuuviLocalization.signalStrengthDbm },
            localized: { RuuviLocalization.signalStrengthDbm($0) }),
        .init(
            key: "signal_strength_with_unit", arguments: [],
            defaultValue: { RuuviLocalization.signalStrengthWithUnit },
            localized: { RuuviLocalization.signalStrengthWithUnit($0) }),
        .init(
            key: "signing_in_is_optional", arguments: [],
            defaultValue: { RuuviLocalization.signingInIsOptional },
            localized: { RuuviLocalization.signingInIsOptional($0) }),
        .init(
            key: "simple_cards", arguments: [],
            defaultValue: { RuuviLocalization.simpleCards },
            localized: { RuuviLocalization.simpleCards($0) }),
        .init(
            key: "sound_average_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.soundAverageWithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.soundAverageWithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "sound_avg", arguments: [],
            defaultValue: { RuuviLocalization.soundAvg },
            localized: { RuuviLocalization.soundAvg($0) }),
        .init(
            key: "sound_instant", arguments: [],
            defaultValue: { RuuviLocalization.soundInstant },
            localized: { RuuviLocalization.soundInstant($0) }),
        .init(
            key: "sound_instant_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.soundInstantWithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.soundInstantWithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "sound_peak", arguments: [],
            defaultValue: { RuuviLocalization.soundPeak },
            localized: { RuuviLocalization.soundPeak($0) }),
        .init(
            key: "sound_peak_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.soundPeakWithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.soundPeakWithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "synchronisation", arguments: [],
            defaultValue: { RuuviLocalization.synchronisation },
            localized: { RuuviLocalization.synchronisation($0) }),
        .init(
            key: "take_photo", arguments: [],
            defaultValue: { RuuviLocalization.takePhoto },
            localized: { RuuviLocalization.takePhoto($0) }),
        .init(
            key: "temperature", arguments: [],
            defaultValue: { RuuviLocalization.temperature },
            localized: { RuuviLocalization.temperature($0) }),
        .init(
            key: "temperature_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.temperatureWithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.temperatureWithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "to_use_all_app_features", arguments: [],
            defaultValue: { RuuviLocalization.toUseAllAppFeatures },
            localized: { RuuviLocalization.toUseAllAppFeatures($0) }),
        .init(
            key: "tutorial_chart_long_tap", arguments: [],
            defaultValue: { RuuviLocalization.tutorialChartLongTap },
            localized: { RuuviLocalization.tutorialChartLongTap($0) }),
        .init(
            key: "type_your_email", arguments: [],
            defaultValue: { RuuviLocalization.typeYourEmail },
            localized: { RuuviLocalization.typeYourEmail($0) }),
        .init(
            key: "unclaim", arguments: [],
            defaultValue: { RuuviLocalization.unclaim },
            localized: { RuuviLocalization.unclaim($0) }),
        .init(
            key: "unclaim_sensor", arguments: [],
            defaultValue: { RuuviLocalization.unclaimSensor },
            localized: { RuuviLocalization.unclaimSensor($0) }),
        .init(
            key: "unclaim_sensor_description", arguments: [],
            defaultValue: { RuuviLocalization.unclaimSensorDescription },
            localized: { RuuviLocalization.unclaimSensorDescription($0) }),
        .init(
            key: "undefined", arguments: [],
            defaultValue: { RuuviLocalization.undefined },
            localized: { RuuviLocalization.undefined($0) }),
        .init(
            key: "unique_id", arguments: [],
            defaultValue: { RuuviLocalization.uniqueId },
            localized: { RuuviLocalization.uniqueId($0) }),
        .init(
            key: "unit_co2", arguments: [],
            defaultValue: { RuuviLocalization.unitCo2 },
            localized: { RuuviLocalization.unitCo2($0) }),
        .init(
            key: "unit_luminosity", arguments: [],
            defaultValue: { RuuviLocalization.unitLuminosity },
            localized: { RuuviLocalization.unitLuminosity($0) }),
        .init(
            key: "unit_nox", arguments: [],
            defaultValue: { RuuviLocalization.unitNox },
            localized: { RuuviLocalization.unitNox($0) }),
        .init(
            key: "unit_pm10", arguments: [],
            defaultValue: { RuuviLocalization.unitPm10 },
            localized: { RuuviLocalization.unitPm10($0) }),
        .init(
            key: "unit_pm100", arguments: [],
            defaultValue: { RuuviLocalization.unitPm100 },
            localized: { RuuviLocalization.unitPm100($0) }),
        .init(
            key: "unit_pm25", arguments: [],
            defaultValue: { RuuviLocalization.unitPm25 },
            localized: { RuuviLocalization.unitPm25($0) }),
        .init(
            key: "unit_pm40", arguments: [],
            defaultValue: { RuuviLocalization.unitPm40 },
            localized: { RuuviLocalization.unitPm40($0) }),
        .init(
            key: "unit_sound", arguments: [],
            defaultValue: { RuuviLocalization.unitSound },
            localized: { RuuviLocalization.unitSound($0) }),
        .init(
            key: "unit_voc", arguments: [],
            defaultValue: { RuuviLocalization.unitVoc },
            localized: { RuuviLocalization.unitVoc($0) }),
    ]
}
