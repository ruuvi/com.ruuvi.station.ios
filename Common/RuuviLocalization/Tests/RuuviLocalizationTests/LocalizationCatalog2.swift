import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog2: [LocalizedStringContract] = [
        .init(
            key: "alert_notification_temperature_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationTemperatureLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationTemperatureLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_voc_high_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationVocHighThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationVocHighThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "alert_notification_voc_low_threshold", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.alertNotificationVocLowThreshold("Sensor 1 🌡️") },
            localized: { RuuviLocalization.alertNotificationVocLowThreshold("Sensor 1 🌡️", $0) }),
        .init(
            key: "all", arguments: [],
            defaultValue: { RuuviLocalization.all },
            localized: { RuuviLocalization.all($0) }),
        .init(
            key: "app_theme", arguments: [],
            defaultValue: { RuuviLocalization.appTheme },
            localized: { RuuviLocalization.appTheme($0) }),
        .init(
            key: "aqi", arguments: [],
            defaultValue: { RuuviLocalization.aqi },
            localized: { RuuviLocalization.aqi($0) }),
        .init(
            key: "aqi_advice_co2_excellent_pm_fair", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2ExcellentPmFair },
            localized: { RuuviLocalization.aqiAdviceCo2ExcellentPmFair($0) }),
        .init(
            key: "aqi_advice_co2_excellent_pm_good", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2ExcellentPmGood },
            localized: { RuuviLocalization.aqiAdviceCo2ExcellentPmGood($0) }),
        .init(
            key: "aqi_advice_co2_excellent_pm_poor", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2ExcellentPmPoor },
            localized: { RuuviLocalization.aqiAdviceCo2ExcellentPmPoor($0) }),
        .init(
            key: "aqi_advice_co2_excellent_pm_verypoor", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2ExcellentPmVerypoor },
            localized: { RuuviLocalization.aqiAdviceCo2ExcellentPmVerypoor($0) }),
        .init(
            key: "aqi_advice_co2_fair_pm_excellent", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2FairPmExcellent },
            localized: { RuuviLocalization.aqiAdviceCo2FairPmExcellent($0) }),
        .init(
            key: "aqi_advice_co2_fair_pm_fair", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2FairPmFair },
            localized: { RuuviLocalization.aqiAdviceCo2FairPmFair($0) }),
        .init(
            key: "aqi_advice_co2_fair_pm_good", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2FairPmGood },
            localized: { RuuviLocalization.aqiAdviceCo2FairPmGood($0) }),
        .init(
            key: "aqi_advice_co2_fair_pm_poor", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2FairPmPoor },
            localized: { RuuviLocalization.aqiAdviceCo2FairPmPoor($0) }),
        .init(
            key: "aqi_advice_co2_fair_pm_verypoor", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2FairPmVerypoor },
            localized: { RuuviLocalization.aqiAdviceCo2FairPmVerypoor($0) }),
        .init(
            key: "aqi_advice_co2_good_pm_excellent", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2GoodPmExcellent },
            localized: { RuuviLocalization.aqiAdviceCo2GoodPmExcellent($0) }),
        .init(
            key: "aqi_advice_co2_good_pm_fair", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2GoodPmFair },
            localized: { RuuviLocalization.aqiAdviceCo2GoodPmFair($0) }),
        .init(
            key: "aqi_advice_co2_good_pm_good", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2GoodPmGood },
            localized: { RuuviLocalization.aqiAdviceCo2GoodPmGood($0) }),
        .init(
            key: "aqi_advice_co2_good_pm_poor", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2GoodPmPoor },
            localized: { RuuviLocalization.aqiAdviceCo2GoodPmPoor($0) }),
        .init(
            key: "aqi_advice_co2_good_pm_verypoor", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2GoodPmVerypoor },
            localized: { RuuviLocalization.aqiAdviceCo2GoodPmVerypoor($0) }),
        .init(
            key: "aqi_advice_co2_poor_pm_excellent", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2PoorPmExcellent },
            localized: { RuuviLocalization.aqiAdviceCo2PoorPmExcellent($0) }),
        .init(
            key: "aqi_advice_co2_poor_pm_fair", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2PoorPmFair },
            localized: { RuuviLocalization.aqiAdviceCo2PoorPmFair($0) }),
        .init(
            key: "aqi_advice_co2_poor_pm_good", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2PoorPmGood },
            localized: { RuuviLocalization.aqiAdviceCo2PoorPmGood($0) }),
        .init(
            key: "aqi_advice_co2_poor_pm_poor", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2PoorPmPoor },
            localized: { RuuviLocalization.aqiAdviceCo2PoorPmPoor($0) }),
        .init(
            key: "aqi_advice_co2_poor_pm_verypoor", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2PoorPmVerypoor },
            localized: { RuuviLocalization.aqiAdviceCo2PoorPmVerypoor($0) }),
        .init(
            key: "aqi_advice_co2_verypoor_pm_excellent", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2VerypoorPmExcellent },
            localized: { RuuviLocalization.aqiAdviceCo2VerypoorPmExcellent($0) }),
        .init(
            key: "aqi_advice_co2_verypoor_pm_fair", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2VerypoorPmFair },
            localized: { RuuviLocalization.aqiAdviceCo2VerypoorPmFair($0) }),
        .init(
            key: "aqi_advice_co2_verypoor_pm_good", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2VerypoorPmGood },
            localized: { RuuviLocalization.aqiAdviceCo2VerypoorPmGood($0) }),
        .init(
            key: "aqi_advice_co2_verypoor_pm_poor", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2VerypoorPmPoor },
            localized: { RuuviLocalization.aqiAdviceCo2VerypoorPmPoor($0) }),
        .init(
            key: "aqi_advice_co2_verypoor_pm_verypoor", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceCo2VerypoorPmVerypoor },
            localized: { RuuviLocalization.aqiAdviceCo2VerypoorPmVerypoor($0) }),
        .init(
            key: "aqi_advice_excellent1", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceExcellent1 },
            localized: { RuuviLocalization.aqiAdviceExcellent1($0) }),
        .init(
            key: "aqi_advice_excellent2", arguments: [],
            defaultValue: { RuuviLocalization.aqiAdviceExcellent2 },
            localized: { RuuviLocalization.aqiAdviceExcellent2($0) }),
    ]
}
