import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog10: [LocalizedStringContract] = [
        .init(
            key: "pm", arguments: [],
            defaultValue: { RuuviLocalization.pm },
            localized: { RuuviLocalization.pm($0) }),
        .init(
            key: "pm10", arguments: [],
            defaultValue: { RuuviLocalization.pm10 },
            localized: { RuuviLocalization.pm10($0) }),
        .init(
            key: "pm100", arguments: [],
            defaultValue: { RuuviLocalization.pm100 },
            localized: { RuuviLocalization.pm100($0) }),
        .init(
            key: "pm100_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.pm100WithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.pm100WithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "pm10_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.pm10WithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.pm10WithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "pm25", arguments: [],
            defaultValue: { RuuviLocalization.pm25 },
            localized: { RuuviLocalization.pm25($0) }),
        .init(
            key: "pm25_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.pm25WithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.pm25WithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "pm40", arguments: [],
            defaultValue: { RuuviLocalization.pm40 },
            localized: { RuuviLocalization.pm40($0) }),
        .init(
            key: "pm40_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.pm40WithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.pm40WithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "poor", arguments: [],
            defaultValue: { RuuviLocalization.poor },
            localized: { RuuviLocalization.poor($0) }),
        .init(
            key: "popup_no_history_data", arguments: [],
            defaultValue: { RuuviLocalization.popupNoHistoryData },
            localized: { RuuviLocalization.popupNoHistoryData($0) }),
        .init(
            key: "prepare_your_sensor_instructions", arguments: [],
            defaultValue: { RuuviLocalization.prepareYourSensorInstructions },
            localized: { RuuviLocalization.prepareYourSensorInstructions($0) }),
        .init(
            key: "pressure", arguments: [],
            defaultValue: { RuuviLocalization.pressure },
            localized: { RuuviLocalization.pressure($0) }),
        .init(
            key: "pressure_pa_unit", arguments: [],
            defaultValue: { RuuviLocalization.pressurePaUnit },
            localized: { RuuviLocalization.pressurePaUnit($0) }),
        .init(
            key: "pressure_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.pressureWithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.pressureWithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "preview", arguments: [],
            defaultValue: { RuuviLocalization.preview },
            localized: { RuuviLocalization.preview($0) }),
        .init(
            key: "previous_sensor", arguments: [],
            defaultValue: { RuuviLocalization.previousSensor },
            localized: { RuuviLocalization.previousSensor($0) }),
        .init(
            key: "reading_history_x", arguments: [Float(13.25)],
            defaultValue: { RuuviLocalization.readingHistoryX(Float(13.25)) },
            localized: { RuuviLocalization.readingHistoryX(Float(13.25), $0) }),
        .init(
            key: "rel_humidity", arguments: [],
            defaultValue: { RuuviLocalization.relHumidity },
            localized: { RuuviLocalization.relHumidity($0) }),
        .init(
            key: "relative_humidity", arguments: [],
            defaultValue: { RuuviLocalization.relativeHumidity },
            localized: { RuuviLocalization.relativeHumidity($0) }),
        .init(
            key: "Remove", arguments: [],
            defaultValue: { RuuviLocalization.remove },
            localized: { RuuviLocalization.remove($0) }),
        .init(
            key: "remove_claimed_sensor_description", arguments: [],
            defaultValue: { RuuviLocalization.removeClaimedSensorDescription },
            localized: { RuuviLocalization.removeClaimedSensorDescription($0) }),
        .init(
            key: "remove_cloud_history_description", arguments: [],
            defaultValue: { RuuviLocalization.removeCloudHistoryDescription },
            localized: { RuuviLocalization.removeCloudHistoryDescription($0) }),
        .init(
            key: "remove_local_sensor_description", arguments: [],
            defaultValue: { RuuviLocalization.removeLocalSensorDescription },
            localized: { RuuviLocalization.removeLocalSensorDescription($0) }),
        .init(
            key: "remove_shared_sensor_description", arguments: [],
            defaultValue: { RuuviLocalization.removeSharedSensorDescription },
            localized: { RuuviLocalization.removeSharedSensorDescription($0) }),
        .init(
            key: "request_code", arguments: [],
            defaultValue: { RuuviLocalization.requestCode },
            localized: { RuuviLocalization.requestCode($0) }),
        .init(
            key: "reset_order", arguments: [],
            defaultValue: { RuuviLocalization.resetOrder },
            localized: { RuuviLocalization.resetOrder($0) }),
        .init(
            key: "reset_order_confirmation", arguments: [],
            defaultValue: { RuuviLocalization.resetOrderConfirmation },
            localized: { RuuviLocalization.resetOrderConfirmation($0) }),
        .init(
            key: "rssi_alert_description", arguments: [],
            defaultValue: { RuuviLocalization.rssiAlertDescription },
            localized: { RuuviLocalization.rssiAlertDescription($0) }),
        .init(
            key: "ruuvi_air", arguments: [],
            defaultValue: { RuuviLocalization.ruuviAir },
            localized: { RuuviLocalization.ruuviAir($0) }),
        .init(
            key: "ruuvi_cloud", arguments: [],
            defaultValue: { RuuviLocalization.ruuviCloud },
            localized: { RuuviLocalization.ruuviCloud($0) }),
        .init(
            key: "ruuvi_tag", arguments: [],
            defaultValue: { RuuviLocalization.ruuviTag },
            localized: { RuuviLocalization.ruuviTag($0) }),
    ]
}
