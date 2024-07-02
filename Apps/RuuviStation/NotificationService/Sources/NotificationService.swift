import RuuviLocalization
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    private enum AlertType: String {
        case temperature
        case humidity
        case pressure
        case signal
        case movement
        case offline
    }

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
    private func getAlertType(from value: String) -> AlertType? {
        switch value.lowercased() {
        case "temperature":
            .temperature
        case "humidity":
            .humidity
        case "pressure":
            .pressure
        case "signal":
            .signal
        case "movement":
            .movement
        case "offline":
            .offline
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

    // swiftlint:disable:next cyclomatic_complexity
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
            case .humidity:
                return RuuviLocalization.alertNotificationHumidityLowThreshold(threshold, locale)
            case .pressure:
                return RuuviLocalization.alertNotificationPressureLowThreshold(threshold, locale)
            case .signal:
                return RuuviLocalization.alertNotificationRssiLowThreshold(threshold, locale)
            case .movement:
                return RuuviLocalization.LocalNotificationsManager.DidMove.title(locale)
            case .offline:
                // No message for alert type under for offline since
                // the trigger is always 'Over' i.e. Sensor has been offline over x mins.
                return ""
            }
        case .over:
            switch alertType {
            case .temperature:
                return RuuviLocalization.alertNotificationTemperatureHighThreshold(threshold, locale)
            case .humidity:
                return RuuviLocalization.alertNotificationHumidityHighThreshold(threshold, locale)
            case .pressure:
                return RuuviLocalization.alertNotificationPressureHighThreshold(threshold, locale)
            case .signal:
                return RuuviLocalization.alertNotificationRssiHighThreshold(threshold, locale)
            case .movement:
                return RuuviLocalization.LocalNotificationsManager.DidMove.title(locale)
            case .offline:
                return RuuviLocalization.alertNotificationOfflineMessage(threshold, locale)
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
