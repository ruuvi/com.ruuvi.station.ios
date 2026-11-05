import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog7: [LocalizedStringContract] = [
        .init(
            key: "h", arguments: [],
            defaultValue: { RuuviLocalization.h },
            localized: { RuuviLocalization.h($0) }),
        .init(
            key: "hide_measurements", arguments: [],
            defaultValue: { RuuviLocalization.hideMeasurements },
            localized: { RuuviLocalization.hideMeasurements($0) }),
        .init(
            key: "history_view", arguments: [],
            defaultValue: { RuuviLocalization.historyView },
            localized: { RuuviLocalization.historyView($0) }),
        .init(
            key: "hour", arguments: [],
            defaultValue: { RuuviLocalization.hour },
            localized: { RuuviLocalization.hour($0) }),
        .init(
            key: "hours", arguments: [],
            defaultValue: { RuuviLocalization.hours },
            localized: { RuuviLocalization.hours($0) }),
        .init(
            key: "humidity", arguments: [],
            defaultValue: { RuuviLocalization.humidity },
            localized: { RuuviLocalization.humidity($0) }),
        .init(
            key: "humidity_relative_unit", arguments: [],
            defaultValue: { RuuviLocalization.humidityRelativeUnit },
            localized: { RuuviLocalization.humidityRelativeUnit($0) }),
        .init(
            key: "illuminance", arguments: [],
            defaultValue: { RuuviLocalization.illuminance },
            localized: { RuuviLocalization.illuminance($0) }),
        .init(
            key: "image_cards", arguments: [],
            defaultValue: { RuuviLocalization.imageCards },
            localized: { RuuviLocalization.imageCards($0) }),
        .init(
            key: "increase_graph_size", arguments: [],
            defaultValue: { RuuviLocalization.increaseGraphSize },
            localized: { RuuviLocalization.increaseGraphSize($0) }),
        .init(
            key: "internet_connection_problem", arguments: [],
            defaultValue: { RuuviLocalization.internetConnectionProblem },
            localized: { RuuviLocalization.internetConnectionProblem($0) }),
        .init(
            key: "latest_measured_value", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.latestMeasuredValue("Sensor 1 🌡️") },
            localized: { RuuviLocalization.latestMeasuredValue("Sensor 1 🌡️", $0) }),
        .init(
            key: "led_brightness_control", arguments: [],
            defaultValue: { RuuviLocalization.ledBrightnessControl },
            localized: { RuuviLocalization.ledBrightnessControl($0) }),
        .init(
            key: "led_brightness_fw_update_message", arguments: [],
            defaultValue: { RuuviLocalization.ledBrightnessFwUpdateMessage },
            localized: { RuuviLocalization.ledBrightnessFwUpdateMessage($0) }),
        .init(
            key: "led_brightness_select_message", arguments: [],
            defaultValue: { RuuviLocalization.ledBrightnessSelectMessage },
            localized: { RuuviLocalization.ledBrightnessSelectMessage($0) }),
        .init(
            key: "led_level_0", arguments: [],
            defaultValue: { RuuviLocalization.ledLevel0 },
            localized: { RuuviLocalization.ledLevel0($0) }),
        .init(
            key: "led_level_1", arguments: [],
            defaultValue: { RuuviLocalization.ledLevel1 },
            localized: { RuuviLocalization.ledLevel1($0) }),
        .init(
            key: "led_level_2", arguments: [],
            defaultValue: { RuuviLocalization.ledLevel2 },
            localized: { RuuviLocalization.ledLevel2($0) }),
        .init(
            key: "led_level_3", arguments: [],
            defaultValue: { RuuviLocalization.ledLevel3 },
            localized: { RuuviLocalization.ledLevel3($0) }),
        .init(
            key: "light", arguments: [],
            defaultValue: { RuuviLocalization.light },
            localized: { RuuviLocalization.light($0) }),
        .init(
            key: "light_theme", arguments: [],
            defaultValue: { RuuviLocalization.lightTheme },
            localized: { RuuviLocalization.lightTheme($0) }),
        .init(
            key: "longer_history_message", arguments: [],
            defaultValue: { RuuviLocalization.longerHistoryMessage },
            localized: { RuuviLocalization.longerHistoryMessage($0) }),
        .init(
            key: "longer_history_title", arguments: [],
            defaultValue: { RuuviLocalization.longerHistoryTitle },
            localized: { RuuviLocalization.longerHistoryTitle($0) }),
        .init(
            key: "low_battery", arguments: [],
            defaultValue: { RuuviLocalization.lowBattery },
            localized: { RuuviLocalization.lowBattery($0) }),
        .init(
            key: "luminosity", arguments: [],
            defaultValue: { RuuviLocalization.luminosity },
            localized: { RuuviLocalization.luminosity($0) }),
        .init(
            key: "luminosity_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.luminosityWithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.luminosityWithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "mac_address", arguments: [],
            defaultValue: { RuuviLocalization.macAddress },
            localized: { RuuviLocalization.macAddress($0) }),
        .init(
            key: "main_view", arguments: [],
            defaultValue: { RuuviLocalization.mainView },
            localized: { RuuviLocalization.mainView($0) }),
        .init(
            key: "marketing_consent_prompt_decline", arguments: [],
            defaultValue: { RuuviLocalization.marketingConsentPromptDecline },
            localized: { RuuviLocalization.marketingConsentPromptDecline($0) }),
        .init(
            key: "marketing_consent_prompt_message", arguments: [],
            defaultValue: { RuuviLocalization.marketingConsentPromptMessage },
            localized: { RuuviLocalization.marketingConsentPromptMessage($0) }),
        .init(
            key: "marketing_consent_prompt_saved", arguments: [],
            defaultValue: { RuuviLocalization.marketingConsentPromptSaved },
            localized: { RuuviLocalization.marketingConsentPromptSaved($0) }),
        .init(
            key: "marketing_consent_prompt_title", arguments: [],
            defaultValue: { RuuviLocalization.marketingConsentPromptTitle },
            localized: { RuuviLocalization.marketingConsentPromptTitle($0) }),
    ]
}
