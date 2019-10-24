import Foundation

class ConnectionPersistenceUserDefaults: ConnectionPersistence {
    
    private let prefs = UserDefaults.standard
    private let keepConnectionArrayUDKey = "ConnectionPersistenceUserDefaults.keepConnection.array"
    private let presentConnectionNotificationsArrayUDKey = "ConnectionPersistenceUserDefaults.presentConnectionNotifications.array"
    private let saveHeartbeatsUDKeyPrefix = "ConnectionPersistenceUserDefaults.saveHeartbeatsUDKeyPrefix."
    private let saveHeartbeatsIntervalUDKeyPrefix = "ConnectionPersistenceUserDefaults.saveHeartbeatsIntervalUDKeyPrefix."
    
    var keepConnectionUUIDs: [String] {
        return prefs.array(forKey: keepConnectionArrayUDKey) as? [String] ?? []
    }
    
    func keepConnection(to uuid: String) -> Bool {
        if let array = prefs.array(forKey: keepConnectionArrayUDKey) as? [String] {
            return array.contains(uuid)
        } else {
            return false
        }
    }
    
    func presentConnectionNotifications(for uuid: String) -> Bool {
        if let array = prefs.array(forKey: presentConnectionNotificationsArrayUDKey) as? [String] {
            return array.contains(uuid)
        } else {
            return false
        }
    }
    
    func setKeepConnection(_ value: Bool, for uuid: String) {
        if value {
            if var array = prefs.array(forKey: keepConnectionArrayUDKey) as? [String] {
                if !array.contains(uuid) {
                    array.append(uuid)
                    NotificationCenter.default.post(name: .ConnectionPersistenceDidStartToKeepConnection, object: nil, userInfo: [ConnectionPersistenceDidStartToKeepConnectionKey.uuid: uuid])
                    prefs.set(array, forKey: keepConnectionArrayUDKey)
                }
            } else {
                var array = [String]()
                array.append(uuid)
                NotificationCenter.default.post(name: .ConnectionPersistenceDidStartToKeepConnection, object: nil, userInfo: [ConnectionPersistenceDidStartToKeepConnectionKey.uuid: uuid])
                prefs.set(array, forKey: keepConnectionArrayUDKey)
            }
        } else {
            if var array = prefs.array(forKey: keepConnectionArrayUDKey) as? [String] {
                if array.contains(uuid) {
                    array.removeAll(where: { $0 == uuid })
                    NotificationCenter.default.post(name: .ConnectionPersistenceDidStopToKeepConnection, object: nil, userInfo: [ConnectionPersistenceDidStopToKeepConnectionKey.uuid: uuid])
                    prefs.set(array, forKey: keepConnectionArrayUDKey)
                }
            }
        }
    }
    
    func setPresentConnectionNotifications(_ value: Bool, for uuid: String) {
        if value {
            if var array = prefs.array(forKey: presentConnectionNotificationsArrayUDKey) as? [String] {
                if !array.contains(uuid) {
                    array.append(uuid)
                    prefs.set(array, forKey: presentConnectionNotificationsArrayUDKey)
                }
            } else {
                var array = [String]()
                array.append(uuid)
                prefs.set(array, forKey: presentConnectionNotificationsArrayUDKey)
            }
        } else {
            if var array = prefs.array(forKey: presentConnectionNotificationsArrayUDKey) as? [String] {
                if array.contains(uuid) {
                    array.removeAll(where: { $0 == uuid })
                    prefs.set(array, forKey: presentConnectionNotificationsArrayUDKey)
                }
            }
        }
    }
    
    func saveHeartbeats(uuid: String) -> Bool {
        return prefs.optionalBool(forKey: saveHeartbeatsUDKeyPrefix + uuid) ?? true
    }
    
    func setSaveHeartbeats(_ value: Bool, uuid: String) {
        prefs.set(value, forKey: saveHeartbeatsUDKeyPrefix + uuid)
    }
    
    func saveHeartbeatsInterval(uuid: String) -> Int {
        return prefs.optionalInt(forKey: saveHeartbeatsIntervalUDKeyPrefix + uuid) ?? 5
    }
    
    func setSaveHeartbeatsInterval(_ value: Int, uuid: String) {
        prefs.set(value, forKey: saveHeartbeatsIntervalUDKeyPrefix + uuid)
    }
}
