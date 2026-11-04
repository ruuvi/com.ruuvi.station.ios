import Foundation
import RuuviLocalization
import UserNotifications

/// Formats remote sensor alerts without retaining a delivery callback after completion.
open class RuuviRemoteNotificationService: UNNotificationServiceExtension {
    private enum TriggerType: String {
        case under
        case over
    }

    private enum Alert: String {
        case temperature
        case relativeHumidity = "humidity"
        case pressure
        case signal
        case movement
        case cloudConnection = "offline"
        case aqi
        case carbonDioxide = "co2"
        case pMatter1 = "pm1"
        case pMatter25 = "pm25"
        case pMatter4 = "pm40"
        case pMatter10 = "pm10"
        case voc
        case nox
        case luminosity
        case soundInstant = "soundinstant"
        case soundAverage = "soundaverage"
        case soundPeak = "soundpeak"
    }

    private let defaults: UserDefaults?
    private static let badgeLock = NSLock()
    static let languageKey = "SettingsUserDegaults.languageUDKey"
    static let badgeKey = "SettingsUserDefaults.notificationsBadgeCount"

    public override init() {
        defaults = UserDefaults(suiteName: "group.com.ruuvi.station.pnservice")
        super.init()
    }

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        super.init()
    }

    open override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        let userInfo = content.userInfo
        let formatLocally: Bool
        if let value = userInfo["showLocallyFormatted"] as? Bool {
            formatLocally = value
        } else {
            formatLocally = (userInfo["showLocallyFormatted"] as? String)?.lowercased() != "false"
        }
        if formatLocally,
            let sensorName = userInfo["name"] as? String,
            let alertType = userInfo["alertType"] as? String,
            let triggerType = userInfo["triggerType"] as? String,
            let threshold = userInfo["thresholdValue"] as? String,
            let alertMessage = userInfo["alertData"] as? String,
            let title = titleForAlert(from: triggerType, alertType: alertType, threshold: threshold)
        {
            content.title = title
            content.subtitle = alertMessage
            content.body = sensorName
        }
        content.badge = NSNumber(value: nextBadge())
        // Formatting is synchronous. Nothing remains to deliver when the extension expires.
        contentHandler(content)
    }

    private func nextBadge() -> Int {
        Self.badgeLock.lock()
        defer { Self.badgeLock.unlock() }
        let previous = max(0, defaults?.integer(forKey: Self.badgeKey) ?? 0)
        let next = previous == Int.max ? Int.max : previous + 1
        defaults?.set(next, forKey: Self.badgeKey)
        return next
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func titleForAlert(from trigger: String, alertType: String, threshold: String) -> String? {
        guard let triggerType = TriggerType(rawValue: trigger.lowercased()),
            let alertType = Alert(rawValue: alertType.lowercased())
        else {
            return nil
        }
        let locale = defaults?.string(forKey: Self.languageKey).map(Locale.init(identifier:)) ?? .current
        switch triggerType {
        case .under:
            switch alertType {
            case .temperature:
                return RuuviLocalization.alertNotificationTemperatureLowThreshold(threshold, locale)
            case .relativeHumidity:
                return RuuviLocalization.alertNotificationHumidityLowThreshold(threshold, locale)
            case .pressure:
                return RuuviLocalization.alertNotificationPressureLowThreshold(threshold, locale)
            case .signal:
                return RuuviLocalization.alertNotificationRssiLowThreshold(threshold, locale)
            case .movement:
                return RuuviLocalization.LocalNotificationsManager.DidMove.title(locale)
            case .cloudConnection:
                // No message for alert type under for offline since
                // the trigger is always 'Over' i.e. Sensor has been offline over x mins.
                return nil
            case .aqi:
                return RuuviLocalization.alertNotificationAqiLowThreshold(threshold, locale)
            case .carbonDioxide:
                return RuuviLocalization.alertNotificationCo2LowThreshold(threshold, locale)
            case .pMatter1:
                return RuuviLocalization.alertNotificationPm1LowThreshold(threshold, locale)
            case .pMatter25:
                return RuuviLocalization.alertNotificationPm25LowThreshold(threshold, locale)
            case .pMatter4:
                return RuuviLocalization.alertNotificationPm4LowThreshold(threshold, locale)
            case .pMatter10:
                return RuuviLocalization.alertNotificationPm10LowThreshold(threshold, locale)
            case .voc:
                return RuuviLocalization.alertNotificationVocLowThreshold(threshold, locale)
            case .nox:
                return RuuviLocalization.alertNotificationNoxLowThreshold(threshold, locale)
            case .soundInstant:
                return RuuviLocalization.alertNotificationSoundInstantLowThreshold(threshold, locale)
            case .soundPeak:
                return RuuviLocalization.alertNotificationSoundPeakLowThreshold(threshold, locale)
            case .soundAverage:
                return RuuviLocalization.alertNotificationSoundAverageLowThreshold(threshold, locale)
            case .luminosity:
                return RuuviLocalization.alertNotificationLuminosityLowThreshold(threshold, locale)
            }
        case .over:
            switch alertType {
            case .temperature:
                return RuuviLocalization.alertNotificationTemperatureHighThreshold(threshold, locale)
            case .relativeHumidity:
                return RuuviLocalization.alertNotificationHumidityHighThreshold(threshold, locale)
            case .pressure:
                return RuuviLocalization.alertNotificationPressureHighThreshold(threshold, locale)
            case .signal:
                return RuuviLocalization.alertNotificationRssiHighThreshold(threshold, locale)
            case .movement:
                return RuuviLocalization.LocalNotificationsManager.DidMove.title(locale)
            case .cloudConnection:
                return RuuviLocalization.alertNotificationOfflineMessage(threshold, locale)
            case .aqi:
                return RuuviLocalization.alertNotificationAqiHighThreshold(threshold, locale)
            case .carbonDioxide:
                return RuuviLocalization.alertNotificationCo2HighThreshold(threshold, locale)
            case .pMatter1:
                return RuuviLocalization.alertNotificationPm1HighThreshold(threshold, locale)
            case .pMatter25:
                return RuuviLocalization.alertNotificationPm25HighThreshold(threshold, locale)
            case .pMatter4:
                return RuuviLocalization.alertNotificationPm4HighThreshold(threshold, locale)
            case .pMatter10:
                return RuuviLocalization.alertNotificationPm10HighThreshold(threshold, locale)
            case .voc:
                return RuuviLocalization.alertNotificationVocHighThreshold(threshold, locale)
            case .nox:
                return RuuviLocalization.alertNotificationNoxHighThreshold(threshold, locale)
            case .soundInstant:
                return RuuviLocalization.alertNotificationSoundInstantHighThreshold(threshold, locale)
            case .soundPeak:
                return RuuviLocalization.alertNotificationSoundPeakHighThreshold(threshold, locale)
            case .soundAverage:
                return RuuviLocalization.alertNotificationSoundAverageHighThreshold(threshold, locale)
            case .luminosity:
                return RuuviLocalization.alertNotificationLuminosityHighThreshold(threshold, locale)
            }
        }
    }
}
