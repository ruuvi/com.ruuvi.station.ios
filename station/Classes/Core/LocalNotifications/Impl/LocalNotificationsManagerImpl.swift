import UserNotifications
import UIKit

enum LocalNotificationType: String {
    case temperature = "temperature"
}

class LocalNotificationsManagerImpl: NSObject, LocalNotificationsManager {
    
    var realmContext: RealmContext!
    var alertService: AlertService!
    var settings: Settings!
    
    var lowTemperatureAlerts = [String: Date]()
    var highTemperatureAlerts = [String: Date]()
    
    private let alertCategory = "com.ruuvi.station.alerts"
    private let alertCategoryDisableAction = "com.ruuvi.station.alerts.disable"
    private let alertCategoryUUIDKey = "uuid"
    private let alertCategoryTypeKey = "type"
    
    private var temperatureDidChangeToken: NSObjectProtocol?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        setupLocalNotifications()
        startObserving()
    }
    
    deinit {
        if let temperatureDidChangeToken = temperatureDidChangeToken {
            NotificationCenter.default.removeObserver(temperatureDidChangeToken)
        }
    }
    
    func showDidConnect(uuid: String) {
        
        let content = UNMutableNotificationContent()
        content.title = "LocalNotificationsManager.DidConnect.title".localized()
        
        if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
            content.subtitle = ruuviTag.name
            content.body = ruuviTag.mac ?? ruuviTag.uuid
        } else {
            content.body = uuid
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func showDidDisconnect(uuid: String) {
        let content = UNMutableNotificationContent()
        content.title = "LocalNotificationsManager.DidDisconnect.title".localized()
        if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
            content.subtitle = ruuviTag.name
            content.body = ruuviTag.mac ?? ruuviTag.uuid
        } else {
            content.body = uuid
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func notifyLowTemperature(for uuid: String, celsius: Double) {
        var needsToShow: Bool
        if let shownDate = lowTemperatureAlerts[uuid] {
            needsToShow = Date().timeIntervalSince(shownDate) > TimeInterval(settings.alertsRepeatingIntervalSeconds)
        } else {
            needsToShow = true
        }
        if needsToShow {
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = "LocalNotificationsManager.LowTemperature.title".localized()
            content.userInfo = [alertCategoryUUIDKey : uuid, alertCategoryTypeKey: LocalNotificationType.temperature.rawValue]
            content.categoryIdentifier = alertCategory
            
            if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
                content.subtitle = ruuviTag.name
                content.body = alertService.temperatureDescription(for: ruuviTag.uuid) ?? (ruuviTag.mac ?? ruuviTag.uuid)
            } else {
                content.body = uuid
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            lowTemperatureAlerts[uuid] = Date()
        }
        
        
    }
    
    func notifyHighTemperature(for uuid: String, celsius: Double) {
        var needsToShow: Bool
        if let shownDate = highTemperatureAlerts[uuid] {
            needsToShow = Date().timeIntervalSince(shownDate) > TimeInterval(settings.alertsRepeatingIntervalSeconds)
        } else {
            needsToShow = true
        }
        if needsToShow {
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = "LocalNotificationsManager.HighTemperature.title".localized()
            content.userInfo = [alertCategoryUUIDKey : uuid, alertCategoryTypeKey: LocalNotificationType.temperature.rawValue]
            if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
                content.subtitle = ruuviTag.name
                content.body = alertService.temperatureDescription(for: ruuviTag.uuid) ?? (ruuviTag.mac ?? ruuviTag.uuid)
            } else {
                content.body = uuid
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            highTemperatureAlerts[uuid] = Date()
        }
    }
    
    
}

// MARK: - Private
extension LocalNotificationsManagerImpl {
    private func startObserving() {
        temperatureDidChangeToken = NotificationCenter.default.addObserver(forName: .AlertServiceTemperatureAlertDidChange, object: nil, queue: .main) { [weak self] (notification) in
            if let userInfo = notification.userInfo, let uuid = userInfo[AlertServiceTemperatureAlertDidChangeKey.uuid] as? String {
                self?.lowTemperatureAlerts[uuid] = nil
                self?.highTemperatureAlerts[uuid] = nil
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
        let disableAction = UNNotificationAction(identifier: alertCategoryDisableAction, title: "LocalNotificationsManager.Disable.button".localized(), options: UNNotificationActionOptions(rawValue: 0))
        let disableAlertCategory =
              UNNotificationCategory(identifier: alertCategory, actions: [disableAction], intentIdentifiers: [], options: .customDismissAction)
        
        nc.setNotificationCategories([disableAlertCategory])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard let uuid = userInfo[alertCategoryUUIDKey] as? String else { completionHandler(); return }
        guard let typeString = userInfo[alertCategoryTypeKey] as? String, let type = LocalNotificationType(rawValue: typeString) else { completionHandler(); return }
           
        switch type {
        case .temperature:
            switch response.actionIdentifier {
            case alertCategoryDisableAction:
                alertService.unregister(type: .temperature(lower: 0, upper: 0), for: uuid)
            default:
                break
            }
        }
        
        completionHandler()
    }

}
