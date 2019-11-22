import UserNotifications

class LocalNotificationsManagerImpl: LocalNotificationsManager {
    
    var realmContext: RealmContext!
    var alertPersistence: AlertPersistence!
    
    var lowTemperatureAlerts = [String: Date]()
    var highTemperatureAlerts = [String: Date]()
    
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
            needsToShow = Date().timeIntervalSince(shownDate) > alertPersistence.temperatureInterval(for: uuid)
        } else {
            needsToShow = true
        }
        if needsToShow {
            let content = UNMutableNotificationContent()
            content.title = "LocalNotificationsManager.LowTemperature.title".localized()
            if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
                content.subtitle = ruuviTag.name
                content.body = ruuviTag.mac ?? ruuviTag.uuid
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
            needsToShow = Date().timeIntervalSince(shownDate) > alertPersistence.temperatureInterval(for: uuid)
        } else {
            needsToShow = true
        }
        if needsToShow {
            let content = UNMutableNotificationContent()
            content.title = "LocalNotificationsManager.HighTemperature.title".localized()
            if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
                content.subtitle = ruuviTag.name
                content.body = ruuviTag.mac ?? ruuviTag.uuid
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
