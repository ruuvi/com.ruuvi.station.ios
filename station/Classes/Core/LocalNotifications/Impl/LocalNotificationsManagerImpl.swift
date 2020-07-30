// swiftlint:disable file_length
import UserNotifications
import UIKit

struct LocalAlertCategory {
    var id: String
    var disable: String
    var uuidKey: String
    var typeKey: String
}

enum LowHighNotificationType: String {
    case temperature
    case relativeHumidity
    case absoluteHumidity
    case dewPoint
    case pressure
}

enum LowHighNotificationReason {
    case high
    case low
}

enum BlastNotificationType: String {
    case connection
    case movement
}

class LocalNotificationsManagerImpl: NSObject, LocalNotificationsManager {

    var ruuviTagTrunk: RuuviTagTrunk!
    var virtualTagTrunk: VirtualTagTrunk!
    var idPersistence: IDPersistence!
    var alertService: AlertService!
    var settings: Settings!
    var errorPresenter: ErrorPresenter!

    var lowTemperatureAlerts = [String: Date]()
    var highTemperatureAlerts = [String: Date]()
    var lowRelativeHumidityAlerts = [String: Date]()
    var highRelativeHumidityAlerts = [String: Date]()
    var lowAbsoluteHumidityAlerts = [String: Date]()
    var highAbsoluteHumidityAlerts = [String: Date]()
    var lowDewPointAlerts = [String: Date]()
    var highDewPointAlerts = [String: Date]()
    var lowPressureAlerts = [String: Date]()
    var highPressureAlerts = [String: Date]()

    private let lowHigh = LocalAlertCategory(id: "com.ruuvi.station.alerts.lh",
                                             disable: "com.ruuvi.station.alerts.lh.disable",
                                             uuidKey: "com.ruuvi.station.alerts.lh.uuid",
                                             typeKey: "com.ruuvi.station.alerts.lh.type")
    private let blast = LocalAlertCategory(id: "com.ruuvi.station.alerts.blast",
                                           disable: "com.ruuvi.station.alerts.blast.disable",
                                           uuidKey: "com.ruuvi.station.alerts.blast.uuid",
                                           typeKey: "com.ruuvi.station.alerts.blast.type")

    private var alertDidChangeToken: NSObjectProtocol?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        setupLocalNotifications()
        startObserving()
    }

    deinit {
        alertDidChangeToken?.invalidate()
    }

    private func id(for uuid: String) -> String {
        var id: String
        if let macId = idPersistence.mac(for: uuid.luid) {
            id = macId.value
        } else {
            id = uuid
        }
        return id
    }

    func showDidConnect(uuid: String) {
        let content = UNMutableNotificationContent()
        content.title = "LocalNotificationsManager.DidConnect.title".localized()
        content.sound = .default
        content.userInfo = [blast.uuidKey: uuid, blast.typeKey: BlastNotificationType.connection.rawValue]
        content.categoryIdentifier = blast.id

        ruuviTagTrunk.readOne(id(for: uuid)).on(success: { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            content.subtitle = ruuviTag.name
            content.body = sSelf.alertService.connectionDescription(for: uuid) ?? ""
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }

    func showDidDisconnect(uuid: String) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = [blast.uuidKey: uuid, blast.typeKey: BlastNotificationType.connection.rawValue]
        content.categoryIdentifier = blast.id
        content.title = "LocalNotificationsManager.DidDisconnect.title".localized()

        ruuviTagTrunk.readOne(id(for: uuid)).on(success: { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            content.subtitle = ruuviTag.name
            content.body = sSelf.alertService.connectionDescription(for: uuid) ?? ""
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }

    func notifyDidMove(for uuid: String, counter: Int) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = [blast.uuidKey: uuid, blast.typeKey: BlastNotificationType.movement.rawValue]
        content.categoryIdentifier = blast.id

        content.title = "LocalNotificationsManager.DidMove.title".localized()

        ruuviTagTrunk.readOne(id(for: uuid)).on(success: { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            content.subtitle = ruuviTag.name
            content.body = sSelf.alertService.movementDescription(for: uuid) ?? ""
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }
}

// MARK: - Notify
extension LocalNotificationsManagerImpl {

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func notify(_ reason: LowHighNotificationReason, _ type: LowHighNotificationType, for uuid: String) {
        var needsToShow: Bool
        var cache: [String: Date]
        switch reason {
        case .low:
            switch type {
            case .temperature:
                cache = lowTemperatureAlerts
            case .relativeHumidity:
                cache = lowRelativeHumidityAlerts
            case .absoluteHumidity:
                cache = lowAbsoluteHumidityAlerts
            case .dewPoint:
                cache = lowDewPointAlerts
            case .pressure:
                cache = lowPressureAlerts
            }
        case .high:
            switch type {
            case .temperature:
                cache = highTemperatureAlerts
            case .relativeHumidity:
                cache = highRelativeHumidityAlerts
            case .absoluteHumidity:
                cache = highAbsoluteHumidityAlerts
            case .dewPoint:
                cache = highDewPointAlerts
            case .pressure:
                cache = highPressureAlerts
            }
        }

        if let shownDate = cache[uuid] {
            needsToShow = Date().timeIntervalSince(shownDate) >
                TimeInterval(settings.alertsRepeatingIntervalMinutes * 60)
        } else {
            needsToShow = true
        }
        if needsToShow {
            let content = UNMutableNotificationContent()
            content.sound = .default
            let title: String
            switch reason {
            case .low:
                switch type {
                case .temperature:
                    title = "LocalNotificationsManager.LowTemperature.title".localized()
                case .relativeHumidity:
                    title = "LocalNotificationsManager.LowRelativeHumidity.title".localized()
                case .absoluteHumidity:
                    title = "LocalNotificationsManager.LowAbsoluteHumidity.title".localized()
                case .dewPoint:
                    title = "LocalNotificationsManager.LowDewPoint.title".localized()
                case .pressure:
                    title = "LocalNotificationsManager.LowPressure.title".localized()
                }
            case .high:
                switch type {
                case .temperature:
                    title = "LocalNotificationsManager.HighTemperature.title".localized()
                case .relativeHumidity:
                    title = "LocalNotificationsManager.HighRelativeHumidity.title".localized()
                case .absoluteHumidity:
                    title = "LocalNotificationsManager.HighAbsoluteHumidity.title".localized()
                case .dewPoint:
                    title = "LocalNotificationsManager.HighDewPoint.title".localized()
                case .pressure:
                    title = "LocalNotificationsManager.HighPressure.title".localized()
                }
            }
            content.title = title
            content.userInfo = [lowHigh.uuidKey: uuid, lowHigh.typeKey: type.rawValue]
            content.categoryIdentifier = lowHigh.id

            let body: String
            switch type {
            case .temperature:
                body = alertService.temperatureDescription(for: uuid) ?? ""
            case .relativeHumidity:
                body = alertService.relativeHumidityDescription(for: uuid) ?? ""
            case .absoluteHumidity:
                body = alertService.absoluteHumidityDescription(for: uuid) ?? ""
            case .dewPoint:
                body = alertService.dewPointDescription(for: uuid) ?? ""
            case .pressure:
                body = alertService.pressureDescription(for: uuid) ?? ""
            }
            content.body = body

            ruuviTagTrunk.readOne(id(for: uuid)).on(success: { ruuviTag in
                content.subtitle = ruuviTag.name
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                let request = UNNotificationRequest(identifier: uuid + type.rawValue,
                                                    content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            })
            virtualTagTrunk.readOne(id(for: uuid)).on(success: { virtualTag in
                content.subtitle = virtualTag.name
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                let request = UNNotificationRequest(identifier: uuid + type.rawValue,
                                                    content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            })

            switch reason {
            case .low:
                switch type {
                case .temperature:
                    lowTemperatureAlerts[uuid] = Date()
                case .relativeHumidity:
                    lowRelativeHumidityAlerts[uuid] = Date()
                case .absoluteHumidity:
                    lowAbsoluteHumidityAlerts[uuid] = Date()
                case .dewPoint:
                    lowDewPointAlerts[uuid] = Date()
                case .pressure:
                    lowPressureAlerts[uuid] = Date()
                }
            case .high:
                switch type {
                case .temperature:
                    highTemperatureAlerts[uuid] = Date()
                case .relativeHumidity:
                    highRelativeHumidityAlerts[uuid] = Date()
                case .absoluteHumidity:
                    highAbsoluteHumidityAlerts[uuid] = Date()
                case .dewPoint:
                    highDewPointAlerts[uuid] = Date()
                case .pressure:
                    highPressureAlerts[uuid] = Date()
                }
            }
        }
    }
}

// MARK: - Private
extension LocalNotificationsManagerImpl {

    // swiftlint:disable:next cyclomatic_complexity
    private func startObserving() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .AlertServiceAlertDidChange,
                         object: nil,
                         queue: .main) { [weak self] (notification) in
            if let userInfo = notification.userInfo,
                let uuid = userInfo[AlertServiceAlertDidChangeKey.uuid] as? String,
                let type = userInfo[AlertServiceAlertDidChangeKey.type] as? AlertType {
                let isOn = self?.alertService.isOn(type: type, for: uuid) ?? false
                switch type {
                case .temperature:
                    self?.lowTemperatureAlerts[uuid] = nil
                    self?.highTemperatureAlerts[uuid] = nil
                    if !isOn {
                        self?.cancel(.temperature, for: uuid)
                    }
                case .relativeHumidity:
                    self?.lowRelativeHumidityAlerts[uuid] = nil
                    self?.highRelativeHumidityAlerts[uuid] = nil
                    if !isOn {
                        self?.cancel(.relativeHumidity, for: uuid)
                    }
                case .absoluteHumidity:
                    self?.lowAbsoluteHumidityAlerts[uuid] = nil
                    self?.highAbsoluteHumidityAlerts[uuid] = nil
                    if !isOn {
                        self?.cancel(.absoluteHumidity, for: uuid)
                    }
                case .dewPoint:
                    self?.lowDewPointAlerts[uuid] = nil
                    self?.highDewPointAlerts[uuid] = nil
                    if !isOn {
                        self?.cancel(.dewPoint, for: uuid)
                    }
                case .pressure:
                    self?.lowPressureAlerts[uuid] = nil
                    self?.highPressureAlerts[uuid] = nil
                    if !isOn {
                        self?.cancel(.pressure, for: uuid)
                    }
                case .connection:
                    // do nothing
                    break
                case .movement:
                    // do nothing
                    break
                }
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension LocalNotificationsManagerImpl: UNUserNotificationCenterDelegate {

    private func setupLocalNotifications() {
        let nc = UNUserNotificationCenter.current()
        nc.delegate = self

        // alerts actions and categories
        let disableLowHighAction = UNNotificationAction(identifier: lowHigh.disable,
                                                        title: "LocalNotificationsManager.Disable.button".localized(),
                                                        options: UNNotificationActionOptions(rawValue: 0))
        let lowHighCategory = UNNotificationCategory(identifier: lowHigh.id,
                                                     actions: [disableLowHighAction],
                                                     intentIdentifiers: [],
                                                     options: .customDismissAction)

        let disableBlastAction = UNNotificationAction(identifier: blast.disable,
                                                      title: "LocalNotificationsManager.Disable.button".localized(),
                                                      options: UNNotificationActionOptions(rawValue: 0))
        let blastCategory = UNNotificationCategory(identifier: blast.id,
                                                   actions: [disableBlastAction],
                                                   intentIdentifiers: [],
                                                   options: .customDismissAction)

        nc.setNotificationCategories([lowHighCategory, blastCategory])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let uuid = userInfo[lowHigh.uuidKey] as? String,
            let typeString = userInfo[lowHigh.typeKey] as? String,
            let type = LowHighNotificationType(rawValue: typeString),
            response.actionIdentifier == lowHigh.disable {
            switch type {
            case .temperature:
                alertService.unregister(type: .temperature(lower: 0, upper: 0), for:
                    uuid)
            case .relativeHumidity:
                alertService.unregister(type: .relativeHumidity(lower: 0, upper: 0), for: uuid)
            case .absoluteHumidity:
                alertService.unregister(type: .absoluteHumidity(lower: 0, upper: 0), for: uuid)
            case .dewPoint:
                alertService.unregister(type: .dewPoint(lower: 0, upper: 0), for: uuid)
            case .pressure:
                alertService.unregister(type: .pressure(lower: 0, upper: 0), for: uuid)
            }
        } else if let uuid = userInfo[blast.uuidKey] as? String,
            let typeString = userInfo[blast.typeKey] as? String,
            let type = BlastNotificationType(rawValue: typeString),
            response.actionIdentifier == blast.disable {
            switch type {
            case .connection:
                alertService.unregister(type: .connection, for: uuid)
            case .movement:
                alertService.unregister(type: .movement(last: 0), for: uuid)
            }
        }

        if let uuid = userInfo[lowHigh.uuidKey] as? String
                     ?? userInfo[blast.uuidKey] as? String {
            NotificationCenter.default.post(name: .LNMDidReceive, object: nil, userInfo: [LNMDidReceiveKey.uuid: uuid])
        }

        completionHandler()
    }

    private func cancel(_ type: LowHighNotificationType, for uuid: String) {
        let nc = UNUserNotificationCenter.current()
        nc.removePendingNotificationRequests(withIdentifiers: [uuid + type.rawValue])
        nc.removeDeliveredNotifications(withIdentifiers: [uuid + type.rawValue])
    }

}
// swiftlint:enable file_length
