import Foundation

class ConnectionPersistenceUserDefaults: ConnectionPersistence {
    
    private let keepConnectionArrayUDKey = "ConnectionPersistenceUserDefaults.keepConnection.array"
    private let presentConnectionNotificationsArrayUDKey = "ConnectionPersistenceUserDefaults.presentConnectionNotifications.array"
    
    var keepConnectionUUIDs: [String] {
        return UserDefaults.standard.array(forKey: keepConnectionArrayUDKey) as? [String] ?? []
    }
    
    func keepConnection(to uuid: String) -> Bool {
        if let array = UserDefaults.standard.array(forKey: keepConnectionArrayUDKey) as? [String] {
            return array.contains(uuid)
        } else {
            return false
        }
    }
    
    func presentConnectionNotifications(for uuid: String) -> Bool {
        if let array = UserDefaults.standard.array(forKey: presentConnectionNotificationsArrayUDKey) as? [String] {
            return array.contains(uuid)
        } else {
            return false
        }
    }
    
    func setKeepConnection(_ value: Bool, for uuid: String) {
        if value {
            if var array = UserDefaults.standard.array(forKey: keepConnectionArrayUDKey) as? [String] {
                if !array.contains(uuid) {
                    array.append(uuid)
                    NotificationCenter.default.post(name: .ConnectionPersistenceDidStartToKeepConnection, object: nil, userInfo: [ConnectionPersistenceDidStartToKeepConnectionKey.uuid: uuid])
                    UserDefaults.standard.set(array, forKey: keepConnectionArrayUDKey)
                }
            } else {
                var array = [String]()
                array.append(uuid)
                NotificationCenter.default.post(name: .ConnectionPersistenceDidStartToKeepConnection, object: nil, userInfo: [ConnectionPersistenceDidStartToKeepConnectionKey.uuid: uuid])
                UserDefaults.standard.set(array, forKey: keepConnectionArrayUDKey)
            }
        } else {
            if var array = UserDefaults.standard.array(forKey: keepConnectionArrayUDKey) as? [String] {
                if array.contains(uuid) {
                    array.removeAll(where: { $0 == uuid })
                    NotificationCenter.default.post(name: .ConnectionPersistenceDidStopToKeepConnection, object: nil, userInfo: [ConnectionPersistenceDidStopToKeepConnectionKey.uuid: uuid])
                    UserDefaults.standard.set(array, forKey: keepConnectionArrayUDKey)
                }
            }
        }
    }
    
    func setPresentConnectionNotifications(_ value: Bool, for uuid: String) {
        if value {
            if var array = UserDefaults.standard.array(forKey: presentConnectionNotificationsArrayUDKey) as? [String] {
                if !array.contains(uuid) {
                    array.append(uuid)
                    UserDefaults.standard.set(array, forKey: presentConnectionNotificationsArrayUDKey)
                }
            } else {
                var array = [String]()
                array.append(uuid)
                UserDefaults.standard.set(array, forKey: presentConnectionNotificationsArrayUDKey)
            }
        } else {
            if var array = UserDefaults.standard.array(forKey: presentConnectionNotificationsArrayUDKey) as? [String] {
                if array.contains(uuid) {
                    array.removeAll(where: { $0 == uuid })
                    UserDefaults.standard.set(array, forKey: presentConnectionNotificationsArrayUDKey)
                }
            }
        }
    }
}
