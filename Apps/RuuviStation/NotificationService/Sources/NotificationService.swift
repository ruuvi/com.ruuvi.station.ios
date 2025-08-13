import RuuviLocalization
import UserNotifications
import RuuviOntology

class NotificationService: UNNotificationServiceExtension {

    private enum TriggerType: String {
        case under
        case over
    }

    private let notificationServiceAppGroup = UserDefaults(suiteName: "group.com.ruuvi.station.pnservice")
    private let languageUDKey = "SettingsUserDegaults.languageUDKey"
    private let notificationsBadgeCountUDKey = "SettingsUserDefaults.notificationsBadgeCount"

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var currentRequest: UNNotificationRequest?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler:
        @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        currentRequest = request
        processNotification()
    }

    override func serviceExtensionTimeWillExpire() {
        processNotification()
    }

    private func processNotification() {
        if let contentHandler,
           let userInfo = currentRequest?.content.userInfo,
           let bestAttemptContent {
            // If this value is not available on data, show formatted message.
            // Otherwise don't do anything.
            var showLocallyFormatted: Bool = true
            // Its a shame that properties from userInfo are always string somehow.
            // So, cast it as string and compare with 'false' value.
            if let showLocallyFormattedMessage = userInfo["showLocallyFormatted"] as? String {
                showLocallyFormatted = showLocallyFormattedMessage != "false"
            }
            if showLocallyFormatted {
                if let sensorName = userInfo["name"] as? String,
                   let alertType = userInfo["alertType"] as? String,
                   let triggerType = userInfo["triggerType"] as? String,
                   let threshold = userInfo["thresholdValue"] as? String,
                   let alertMessage = userInfo["alertData"] as? String {
                    let title = titleForAlert(
                        from: triggerType,
                        alertType: alertType,
                        threshold: threshold
                    )
                    bestAttemptContent.subtitle = alertMessage
                    bestAttemptContent.title = title
                    bestAttemptContent.body = sensorName
                }
            }
            setAlertBadge(for: bestAttemptContent)

            contentHandler(bestAttemptContent)
        }
    }
}

extension NotificationService {

    // swiftlint:disable:next cyclomatic_complexity
    private func getAlertType(from value: String) -> AlertType? {
        switch value.lowercased() {
        case "temperature":
                .temperature(lower: 0, upper: 0)
        case "humidity":
            .relativeHumidity(lower: 0, upper: 0)
        case "pressure":
            .pressure(lower: 0, upper: 0)
        case "signal":
            .signal(lower: 0, upper: 0)
        case "movement":
                .movement(last: 0)
        case "offline":
                .cloudConnection(unseenDuration: 0)
        case "aqi":
                .aqi(lower: 0, upper: 0)
        case "co2":
                .carbonDioxide(lower: 0, upper: 0)
        case "pm1":
                .pMatter1(lower: 0, upper: 0)
        case "pm25":
                .pMatter25(lower: 0, upper: 0)
        case "pm40":
                .pMatter4(lower: 0, upper: 0)
        case "pm10":
                .pMatter10(lower: 0, upper: 0)
        case "voc":
                .voc(lower: 0, upper: 0)
        case "nox":
                .nox(lower: 0, upper: 0)
        case "luminosity":
                .luminosity(lower: 0, upper: 0)
        case "soundInstant":
                .soundInstant(lower: 0, upper: 0)
        case "soundAverage":
                .soundAverage(lower: 0, upper: 0)
        case "soundPeak":
                .soundPeak(lower: 0, upper: 0)
        default:
            nil
        }
    }

    private func getTriggerType(from value: String) -> TriggerType? {
        switch value.lowercased() {
        case "under":
            .under
        case "over":
            .over
        default:
            nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func titleForAlert(
        from triggerType: String,
        alertType: String,
        threshold: String
    ) -> String {
        guard let triggerType = getTriggerType(from: triggerType),
              let alertType = getAlertType(from: alertType)
        else {
            return ""
        }

        let locale: Locale
        if let languageCode = notificationServiceAppGroup?.string(forKey: languageUDKey) {
            locale = Locale(identifier: languageCode)
        } else {
            locale = .current
        }

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
                return ""
            case .aqi:
                return RuuviLocalization.alertNotificationAqiLowThreshold(threshold, locale)
            case .carbonDioxide:
                return RuuviLocalization.alertNotificationCo2LowThreshold(threshold, locale)
            case .pMatter1:
                return RuuviLocalization.alertNotificationPm10LowThreshold(threshold, locale)
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
            default:
                return ""
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
            default:
                return ""
            }
        }
    }

    private func setAlertBadge(for content: UNMutableNotificationContent) {
        let currentValue = notificationServiceAppGroup?
            .integer(
                forKey: notificationsBadgeCountUDKey
            ) ?? 0
        notificationServiceAppGroup?
            .set(
                currentValue + 1,
                forKey: notificationsBadgeCountUDKey
            )
        content.badge = (currentValue + 1) as NSNumber
    }
}
