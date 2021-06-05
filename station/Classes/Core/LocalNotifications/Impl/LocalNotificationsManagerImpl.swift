// swiftlint:disable file_length
import UserNotifications
import UIKit
import RuuviOntology
import RuuviStorage
import RuuviLocal
import RuuviService

struct LocalAlertCategory {
    var id: String
    var disable: String
    var mute: String
    var uuidKey: String
    var typeKey: String
}

enum LowHighNotificationType: String {
    case temperature
    case humidity
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

    var ruuviStorage: RuuviStorage!
    var virtualTagTrunk: VirtualTagTrunk!
    var idPersistence: RuuviLocalIDs!
    var alertService: AlertService!
    var settings: RuuviLocalSettings!
    var errorPresenter: ErrorPresenter!
    var ruuviAlertService: RuuviServiceAlert!

    var lowTemperatureAlerts = [String: Date]()
    var highTemperatureAlerts = [String: Date]()
    var lowHumidityAlerts = [String: Date]()
    var highHumidityAlerts = [String: Date]()
    var lowDewPointAlerts = [String: Date]()
    var highDewPointAlerts = [String: Date]()
    var lowPressureAlerts = [String: Date]()
    var highPressureAlerts = [String: Date]()

    private let lowHigh = LocalAlertCategory(
        id: "com.ruuvi.station.alerts.lh",
        disable: "com.ruuvi.station.alerts.lh.disable",
        mute: "com.ruuvi.station.alerts.lh.mute",
        uuidKey: "com.ruuvi.station.alerts.lh.uuid",
        typeKey: "com.ruuvi.station.alerts.lh.type"
    )
    private let blast = LocalAlertCategory(
        id: "com.ruuvi.station.alerts.blast",
        disable: "com.ruuvi.station.alerts.blast.disable",
        mute: "com.ruuvi.station.alerts.blast.mute",
        uuidKey: "com.ruuvi.station.alerts.blast.uuid",
        typeKey: "com.ruuvi.station.alerts.blast.type"
    )

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
        if let mutedTill = ruuviAlertService.mutedTill(type: .connection, for: uuid),
           mutedTill > Date() {
            return // muted
        }

        let content = UNMutableNotificationContent()
        content.title = "LocalNotificationsManager.DidConnect.title".localized()
        content.sound = .default
        content.userInfo = [blast.uuidKey: uuid, blast.typeKey: BlastNotificationType.connection.rawValue]
        content.categoryIdentifier = blast.id

        ruuviStorage.readOne(id(for: uuid)).on(success: { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            content.subtitle = ruuviTag.name
            content.body = sSelf.ruuviAlertService.connectionDescription(for: uuid) ?? ""
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }

    func showDidDisconnect(uuid: String) {
        if let mutedTill = ruuviAlertService.mutedTill(type: .connection, for: uuid),
           mutedTill > Date() {
            return // muted
        }
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = [blast.uuidKey: uuid, blast.typeKey: BlastNotificationType.connection.rawValue]
        content.categoryIdentifier = blast.id
        content.title = "LocalNotificationsManager.DidDisconnect.title".localized()

        ruuviStorage.readOne(id(for: uuid)).on(success: { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            content.subtitle = ruuviTag.name
            content.body = sSelf.ruuviAlertService.connectionDescription(for: uuid) ?? ""
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }

    func notifyDidMove(for uuid: String, counter: Int) {
        if let mutedTill = ruuviAlertService.mutedTill(type: .movement(last: 0), for: uuid),
           mutedTill > Date() {
            return // muted
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = [blast.uuidKey: uuid, blast.typeKey: BlastNotificationType.movement.rawValue]
        content.categoryIdentifier = blast.id

        content.title = "LocalNotificationsManager.DidMove.title".localized()

        ruuviStorage.readOne(id(for: uuid)).on(success: { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            content.subtitle = ruuviTag.name
            content.body = sSelf.ruuviAlertService.movementDescription(for: uuid) ?? ""
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
            case .humidity:
                cache = lowHumidityAlerts
            case .dewPoint:
                cache = lowDewPointAlerts
            case .pressure:
                cache = lowPressureAlerts
            }
        case .high:
            switch type {
            case .temperature:
                cache = highTemperatureAlerts
            case .humidity:
                cache = highHumidityAlerts
            case .dewPoint:
                cache = highDewPointAlerts
            case .pressure:
                cache = highPressureAlerts
            }
        }

        if let shownDate = cache[uuid] {
            let intervalPassed = Date().timeIntervalSince(shownDate) >=
                TimeInterval(settings.saveHeartbeatsIntervalMinutes * 60)
            if let mutedTill = ruuviAlertService.mutedTill(type: Self.alertType(from: type), for: uuid) {
                needsToShow = intervalPassed && (Date() > mutedTill)
            } else {
                needsToShow = intervalPassed
            }
        } else if let mutedTill = ruuviAlertService.mutedTill(type: Self.alertType(from: type), for: uuid) {
            needsToShow = Date() > mutedTill
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
                case .humidity:
                    title = "LocalNotificationsManager.LowHumidity.title".localized()
                case .dewPoint:
                    title = "LocalNotificationsManager.LowDewPoint.title".localized()
                case .pressure:
                    title = "LocalNotificationsManager.LowPressure.title".localized()
                }
            case .high:
                switch type {
                case .temperature:
                    title = "LocalNotificationsManager.HighTemperature.title".localized()
                case .humidity:
                    title = "LocalNotificationsManager.HighHumidity.title".localized()
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
                body = ruuviAlertService.temperatureDescription(for: uuid) ?? ""
            case .humidity:
                body = ruuviAlertService.humidityDescription(for: uuid) ?? ""
            case .dewPoint:
                body = ruuviAlertService.dewPointDescription(for: uuid) ?? ""
            case .pressure:
                body = ruuviAlertService.pressureDescription(for: uuid) ?? ""
            }
            content.body = body

            ruuviStorage.readOne(id(for: uuid)).on(success: { ruuviTag in
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
                case .humidity:
                    lowHumidityAlerts[uuid] = Date()
                case .dewPoint:
                    lowDewPointAlerts[uuid] = Date()
                case .pressure:
                    lowPressureAlerts[uuid] = Date()
                }
            case .high:
                switch type {
                case .temperature:
                    highTemperatureAlerts[uuid] = Date()
                case .humidity:
                    highHumidityAlerts[uuid] = Date()
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
    private static func alertType(from type: LowHighNotificationType) -> AlertType {
        switch type {
        case .temperature:
            return .temperature(lower: 0, upper: 0)
        case .humidity:
            return .humidity(
                lower: Humidity(value: 0, unit: .absolute),
                upper: Humidity(value: 0, unit: .absolute)
            )
        case .dewPoint:
            return .dewPoint(lower: 0, upper: 0)
        case .pressure:
            return .pressure(lower: 0, upper: 0)
        }
    }

    private static func alertType(from type: BlastNotificationType) -> AlertType {
        switch type {
        case .connection:
            return .connection
        case .movement:
            return .movement(last: 0)
        }
    }

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
                let isOn = self?.ruuviAlertService.isOn(type: type, for: uuid) ?? false
                switch type {
                case .temperature:
                    self?.lowTemperatureAlerts[uuid] = nil
                    self?.highTemperatureAlerts[uuid] = nil
                    if !isOn {
                        self?.cancel(.temperature, for: uuid)
                    }
                case .humidity:
                    self?.lowHumidityAlerts[uuid] = nil
                    self?.highHumidityAlerts[uuid] = nil
                    if !isOn {
                        self?.cancel(.humidity, for: uuid)
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
        let disableLowHighAction = UNNotificationAction(
            identifier: lowHigh.disable,
            title: "LocalNotificationsManager.Disable.button".localized(),
            options: UNNotificationActionOptions(rawValue: 0)
        )
        let muteLowHighAction = UNNotificationAction(
            identifier: lowHigh.mute,
            title: "LocalNotificationsManager.Mute.button".localized(),
            options: UNNotificationActionOptions(rawValue: 0)
        )
        let lowHighCategory = UNNotificationCategory(
            identifier: lowHigh.id,
            actions: [muteLowHighAction, disableLowHighAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let disableBlastAction = UNNotificationAction(
            identifier: blast.disable,
            title: "LocalNotificationsManager.Disable.button".localized(),
            options: UNNotificationActionOptions(rawValue: 0)
        )
        let muteBlastAction = UNNotificationAction(
            identifier: blast.mute,
            title: "LocalNotificationsManager.Mute.button".localized(),
            options: UNNotificationActionOptions(rawValue: 0)
        )
        let blastCategory = UNNotificationCategory(
            identifier: blast.id,
            actions: [muteBlastAction, disableBlastAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

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
            let type = LowHighNotificationType(rawValue: typeString) {
            switch response.actionIdentifier {
            case lowHigh.disable:
                ruuviAlertService.unregister(type: Self.alertType(from: type), for: uuid)
            case lowHigh.mute:
                mute(type: type, uuid: uuid)
            default:
                break
            }

        } else if let uuid = userInfo[blast.uuidKey] as? String,
            let typeString = userInfo[blast.typeKey] as? String,
            let type = BlastNotificationType(rawValue: typeString) {
            switch response.actionIdentifier {
            case blast.disable:
                ruuviAlertService.unregister(type: Self.alertType(from: type), for: uuid)
            case blast.mute:
                mute(type: type, uuid: uuid)
            default:
                break
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

    private func mute(type: LowHighNotificationType, uuid: String) {
        guard let date = muteOffset() else {
            assertionFailure(); return
        }
        ruuviAlertService.mute(
            type: Self.alertType(from: type),
            for: uuid,
            till: date
        )
    }

    private func mute(type: BlastNotificationType, uuid: String) {
        guard let date = muteOffset() else {
            assertionFailure(); return
        }
        ruuviAlertService.mute(
            type: Self.alertType(from: type),
            for: uuid, till: date
        )
    }

    private func muteOffset() -> Date? {
        return Calendar.current.date(
            byAdding: .minute,
            value: self.settings.alertsMuteIntervalMinutes,
            to: Date()
        )
    }
}
// swiftlint:enable file_length
