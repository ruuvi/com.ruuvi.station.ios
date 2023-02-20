import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    // swiftlint:disable redundant_string_enum_value
    private enum AlertType: String {
        case temperature = "temperature"
        case humidity = "humidity"
        case pressure = "pressure"
        case signal = "signal"
        case movement = "movement"
    }

    private enum TriggerType: String {
        case under = "under"
        case over = "over"
    }
    // swiftlint:enable redundant_string_enum_value

    private let notificationServiceAppGroup = UserDefaults(suiteName: "group.com.ruuvi.station.pnservice")

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var currentRequest: UNNotificationRequest?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler
                             contentHandler:
                             @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        currentRequest = request
        processNotification()
    }

    override func serviceExtensionTimeWillExpire() {
        processNotification()
    }

    private func processNotification() {

        if let contentHandler = contentHandler,
           let alertType = currentRequest?.content.userInfo["alertType"] as? String,
           let triggerType = currentRequest?.content.userInfo["triggerType"] as? String,
           let threshold = currentRequest?.content.userInfo["thresholdValue"] as? String,
           let alertUnit = currentRequest?.content.userInfo["alertUnit"] as? String,
           let bodyValue = currentRequest?.content.userInfo["alertData"] as? String,
           let bestAttemptContent = bestAttemptContent {
            let title = titleForAlert(from: triggerType,
                                      alertType: alertType,
                                      threshold: threshold,
                                      alertUnit: alertUnit)
            bestAttemptContent.title = title
            bestAttemptContent.body = bodyValue
            contentHandler(bestAttemptContent)
        }
    }
}

extension NotificationService {
    private func getAlertType(from value: String) -> AlertType? {
        switch value.lowercased() {
        case "temperature":
            return .temperature
        case "humidity":
            return .humidity
        case "pressure":
            return .pressure
        case "signal":
            return .signal
        case "movement":
            return .movement
        default:
            return nil
        }
    }

    private func getTriggerType(from value: String) -> TriggerType? {
        switch value.lowercased() {
        case "under":
            return .under
        case "over":
            return .over
        default:
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func titleForAlert(from triggerType: String,
                               alertType: String,
                               threshold: String,
                               alertUnit: String) -> String {
        guard let triggerType = getTriggerType(from: triggerType),
              let alertType = getAlertType(from: alertType) else {
            return ""
        }

        var format: String = ""
        switch triggerType {
        case .under:
            switch alertType {
            case .temperature:
                format = "alert_notification_temperature_low_threshold"
            case .humidity:
                format =  "alert_notification_humidity_low_threshold"
            case .pressure:
                format = "alert_notification_pressure_low_threshold"
            case .signal:
                format = "alert_notification_rssi_low_threshold"
            case .movement:
                let format = "LocalNotificationsManager.DidMove.title"
                return localized(value: format)
            }
        case .over:
            switch alertType {
            case .temperature:
                format = "alert_notification_temperature_high_threshold"
            case .humidity:
                format =  "alert_notification_humidity_high_threshold"
            case .pressure:
                format = "alert_notification_pressure_high_threshold"
            case .signal:
                format = "alert_notification_rssi_high_threshold"
            case .movement:
                let format = "LocalNotificationsManager.DidMove.title"
                return localized(value: format)
            }
        }

        return String(format: localized(value: format), threshold) + alertUnit
    }

    private func localized(value: String) -> String {
        let languageUDKey = "SettingsUserDegaults.languageUDKey"
        guard let languageCode = notificationServiceAppGroup?.string(forKey: languageUDKey),
              let bundle = Bundle.main.path(
            forResource: languageCode,
            ofType: "lproj"
        ),
              let languageBundle = Bundle(path: bundle) else {
            return NSLocalizedString(value, comment: value)
        }

        return NSLocalizedString(value,
                                 tableName: nil,
                                 bundle: languageBundle,
                                 comment: value)
    }
}
