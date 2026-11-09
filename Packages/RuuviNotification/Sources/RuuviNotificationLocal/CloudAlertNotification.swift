import Foundation
import Future
import RuuviCloud
import RuuviOntology
import RuuviService
import RuuviStorage
import RuuviUser
import UserNotifications

struct CloudAlertNotification {
    static let categoryIdentifier = "com.ruuvi.station.alerts.cloud"
    static let disableActionIdentifier = "com.ruuvi.station.alerts.cloud.disable"

    let sensorID: String
    let alertType: AlertType
    let cloudAlertType: RuuviCloudAlertType
    let email: String

    init?(userInfo: [AnyHashable: Any]) {
        guard let sensorID = userInfo["id"] as? String,
              sensorID.utf8.count == 17,
              sensorID.range(of: "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", options: .regularExpression) != nil,
              let rawType = userInfo["alertType"] as? String,
              let cloudType = RuuviCloudAlertType(rawValue: rawType),
              let alertType = Self.alertTypes[cloudType],
              let email = userInfo["email"] as? String,
              !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self.sensorID = sensorID.uppercased()
        self.alertType = alertType
        self.cloudAlertType = cloudType
        self.email = email
    }

    static func category(disableTitle: String) -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [UNNotificationAction(identifier: disableActionIdentifier, title: disableTitle, options: [])],
            intentIdentifiers: [],
            options: []
        )
    }

    // Identify the local alert kind; saved bounds are resolved only after cloud success.
    private static let alertTypes: [RuuviCloudAlertType: AlertType] = [
        .temperature: .temperature(lower: 0, upper: 0),
        .humidity: .relativeHumidity(lower: 0, upper: 0),
        .humidityAbsolute: .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
        .dewPoint: .dewPoint(lower: 0, upper: 0),
        .pressure: .pressure(lower: 0, upper: 0),
        .signal: .signal(lower: 0, upper: 0),
        .battery: .batteryVoltage(lower: 0, upper: 0),
        .movement: .movement(last: 0),
        .offline: .cloudConnection(unseenDuration: 0),
        .aqi: .aqi(lower: 0, upper: 0),
        .co2: .carbonDioxide(lower: 0, upper: 0),
        .pm10: .pMatter1(lower: 0, upper: 0),
        .pm25: .pMatter25(lower: 0, upper: 0),
        .pm40: .pMatter4(lower: 0, upper: 0),
        .pm100: .pMatter10(lower: 0, upper: 0),
        .voc: .voc(lower: 0, upper: 0),
        .nox: .nox(lower: 0, upper: 0),
        .soundInstant: .soundInstant(lower: 0, upper: 0),
        .soundAverage: .soundAverage(lower: 0, upper: 0),
        .soundPeak: .soundPeak(lower: 0, upper: 0),
        .luminosity: .luminosity(lower: 0, upper: 0),
    ]
}

final class CloudAlertNotificationHandler {
    struct Session: Equatable {
        let email: String
        let apiKey: String
    }

    private let currentSession: () -> Session?
    private let readSensor: (String) -> Future<AnyRuuviTagSensor, RuuviStorageError>
    private let disableAlert: (RuuviCloudAlertType, MACIdentifier) -> Future<Void, RuuviCloudError>

    private let disableLocalAlert: (AlertType, AnyRuuviTagSensor) -> Void

    init(
        currentSession: @escaping () -> Session?,
        readSensor: @escaping (String) -> Future<AnyRuuviTagSensor, RuuviStorageError>,
        disableAlert: @escaping (RuuviCloudAlertType, MACIdentifier) -> Future<Void, RuuviCloudError>,
        disableLocalAlert: @escaping (AlertType, AnyRuuviTagSensor) -> Void
    ) {
        self.currentSession = currentSession
        self.readSensor = readSensor
        self.disableAlert = disableAlert
        self.disableLocalAlert = disableLocalAlert
    }

    convenience init(
        ruuviStorage: RuuviStorage,
        ruuviAlertService: RuuviServiceAlert,
        ruuviUser: RuuviUser,
        ruuviCloud: RuuviCloud
    ) {
        self.init(
            currentSession: {
                guard ruuviUser.isAuthorized,
                      let email = ruuviUser.email,
                      let apiKey = ruuviUser.apiKey else { return nil }
                return .init(email: email, apiKey: apiKey)
            },
            readSensor: ruuviStorage.readOne,
            disableAlert: { type, macId in
                // Omitted fields retain the server's current settings, including
                // thresholds, movement counter, offline delay and description.
                ruuviCloud.setAlert(
                    type: type, settingType: .state, isEnabled: false,
                    min: nil, max: nil, counter: nil, delay: nil, description: nil,
                    for: macId
                )
            },
            disableLocalAlert: { type, sensor in
                guard let configuredType = ruuviAlertService.alert(for: sensor, of: type) else { return }
                ruuviAlertService.unregister(type: configuredType, for: sensor)
            }
        )
    }

    func handle(userInfo: [AnyHashable: Any], completion: @escaping () -> Void) {
        guard let notification = CloudAlertNotification(userInfo: userInfo),
              let session = currentSession(),
              !session.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              session.email.caseInsensitiveCompare(notification.email) == .orderedSame else {
            completion()
            return
        }
        readSensor(notification.sensorID).on(success: { [self] sensor in
            guard currentSession() == session,
                  sensor.isCloud,
                  let macId = sensor.macId,
                  macId.value.uppercased() == notification.sensorID else {
                completion()
                return
            }
            // Complete the notification response after the cloud request finishes.
            disableAlert(notification.cloudAlertType, macId).on(success: { [self] in
                guard currentSession() == session else { return }
                disableLocalAlert(notification.alertType, sensor)
            }, completion: completion)
        }, failure: { _ in
            completion()
        })
    }
}
