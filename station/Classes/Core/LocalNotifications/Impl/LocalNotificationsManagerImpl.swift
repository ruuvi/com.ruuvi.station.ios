import UserNotifications

class LocalNotificationsManagerImpl: LocalNotificationsManager {
    
    var realmContext: RealmContext!
    var alertPersistence: AlertPersistence!
    
    var lowTemperatureAlerts = [String: Date]()
    var highTemperatureAlerts = [String: Date]()
    
    private var temperatureDidChangeToken: NSObjectProtocol?
    
    init() {
        temperatureDidChangeToken = NotificationCenter.default.addObserver(forName: .AlertServiceTemperatureAlertDidChange, object: nil, queue: .main) { [weak self] (notification) in
            if let userInfo = notification.userInfo, let uuid = userInfo[AlertServiceTemperatureAlertDidChangeKey.uuid] as? String {
                self?.lowTemperatureAlerts[uuid] = nil
                self?.highTemperatureAlerts[uuid] = nil
            }
        }
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
            needsToShow = Date().timeIntervalSince(shownDate) > 60 * 60
        } else {
            needsToShow = true
        }
        if needsToShow {
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = "LocalNotificationsManager.LowTemperature.title".localized()
            if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
                content.subtitle = ruuviTag.name
                content.body = alertPersistence.temperatureDescription(for: ruuviTag.uuid) ?? (ruuviTag.mac ?? ruuviTag.uuid)
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
            needsToShow = Date().timeIntervalSince(shownDate) > 60 * 60
        } else {
            needsToShow = true
        }
        if needsToShow {
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = "LocalNotificationsManager.HighTemperature.title".localized()
            if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
                content.subtitle = ruuviTag.name
                content.body = alertPersistence.temperatureDescription(for: ruuviTag.uuid) ?? (ruuviTag.mac ?? ruuviTag.uuid)
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
