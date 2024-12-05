import Foundation
import RuuviLocalization
import RuuviNotifier

struct RuuviNotifierTitlesImpl: RuuviNotifierTitles {
    func lowTemperature(_ value: String) -> String {
        RuuviLocalization.alertNotificationTemperatureLowThreshold(value)
    }

    func highTemperature(_ value: String) -> String {
        RuuviLocalization.alertNotificationTemperatureHighThreshold(value)
    }

    func lowHumidity(_ value: String) -> String {
        RuuviLocalization.alertNotificationHumidityLowThreshold(value)
    }

    func highHumidity(_ value: String) -> String {
        RuuviLocalization.alertNotificationHumidityHighThreshold(value)
    }

    func lowPressure(_ value: String) -> String {
        RuuviLocalization.alertNotificationPressureLowThreshold(value)
    }

    func highPressure(_ value: String) -> String {
        RuuviLocalization.alertNotificationPressureHighThreshold(value)
    }

    func lowSignal(_ value: String) -> String {
        RuuviLocalization.alertNotificationRssiLowThreshold(value)
    }

    func highSignal(_ value: String) -> String {
        RuuviLocalization.alertNotificationRssiHighThreshold(value)
    }

    func lowCarbonDioxide(_ value: String) -> String {
        RuuviLocalization.alertNotificationCo2LowThreshold(value)
    }

    func highCarbonDioxide(_ value: String) -> String {
        RuuviLocalization.alertNotificationCo2HighThreshold(value)
    }

    func lowPMatter1(_ value: String) -> String {
        RuuviLocalization.alertNotificationPm1LowThreshold(value)
    }

    func highPMatter1(_ value: String) -> String {
        RuuviLocalization.alertNotificationPm1HighThreshold(value)
    }

    func lowPMatter2_5(_ value: String) -> String {
        RuuviLocalization.alertNotificationPm25LowThreshold(value)
    }

    func highPMatter2_5(_ value: String) -> String {
        RuuviLocalization.alertNotificationPm25HighThreshold(value)
    }

    func lowPMatter4(_ value: String) -> String {
        RuuviLocalization.alertNotificationPm4LowThreshold(value)
    }

    func highPMatter4(_ value: String) -> String {
        RuuviLocalization.alertNotificationPm4HighThreshold(value)
    }

    func lowPMatter10(_ value: String) -> String {
        RuuviLocalization.alertNotificationPm10LowThreshold(value)
    }

    func highPMatter10(_ value: String) -> String {
        RuuviLocalization.alertNotificationPm10HighThreshold(value)
    }

    func lowVOC(_ value: String) -> String {
        RuuviLocalization.alertNotificationVocLowThreshold(value)
    }

    func highVOC(_ value: String) -> String {
        RuuviLocalization.alertNotificationVocHighThreshold(value)
    }

    func lowNOx(_ value: String) -> String {
        RuuviLocalization.alertNotificationNoxLowThreshold(value)
    }

    func highNOx(_ value: String) -> String {
        RuuviLocalization.alertNotificationNoxHighThreshold(value)
    }

    func lowSound(_ value: String) -> String {
        RuuviLocalization.alertNotificationSoundLowThreshold(value)
    }

    func highSound(_ value: String) -> String {
        RuuviLocalization.alertNotificationSoundHighThreshold(value)
    }

    func lowLuminosity(_ value: String) -> String {
        RuuviLocalization.alertNotificationLuminosityLowThreshold(value)
    }

    func highLuminosity(_ value: String) -> String {
        RuuviLocalization.alertNotificationLuminosityHighThreshold(value)
    }

    let didMove = RuuviLocalization.LocalNotificationsManager.DidMove.title
}
