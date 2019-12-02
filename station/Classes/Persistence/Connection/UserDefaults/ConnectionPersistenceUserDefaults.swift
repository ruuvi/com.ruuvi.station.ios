import Foundation

class ConnectionPersistenceUserDefaults: ConnectionPersistence {

    private let prefs = UserDefaults.standard
    private let keepConnectionArrayUDKey = "ConnectionPersistenceUserDefaults.keepConnection.array"
    private let presentConnectionNotificationsArrayUDKey = "ConnectionPersistenceUserDefaults.presentConnectionNotifications.array"
    private let saveHeartbeatsUDKeyPrefix = "ConnectionPersistenceUserDefaults.saveHeartbeatsUDKeyPrefix."
    private let saveHeartbeatsIntervalUDKeyPrefix = "ConnectionPersistenceUserDefaults.saveHeartbeatsIntervalUDKeyPrefix."
    private let readRSSIArrayUDKey = "ConnectionPersistenceUserDefaults.readRSSIArrayUDKey.array"
    private let readRSSIIntervalUDKeyPrefix = "ConnectionPersistenceUserDefaults.readRSSIIntervalUDKeyPrefix."
    private let logSyncDateUDKeyPrefix = "ConnectionPersistenceUserDefaults.logSyncDateUDKeyPrefix."

    var keepConnectionUUIDs: [String] {
        return prefs.array(forKey: keepConnectionArrayUDKey) as? [String] ?? []
    }

    var readRSSIUUIDs: [String] {
        return prefs.array(forKey: readRSSIArrayUDKey) as? [String] ?? []
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
                    prefs.set(array, forKey: keepConnectionArrayUDKey)
                    NotificationCenter.default.post(name: .ConnectionPersistenceDidStartToKeepConnection,
                                                    object: nil,
                                                    userInfo: [ConnectionPersistenceDidStartToKeepConnectionKey.uuid: uuid,
                                                               ConnectionPersistenceDidStartToKeepConnectionKey.readRSSI: readRSSI(uuid: uuid)])
                }
            } else {
                var array = [String]()
                array.append(uuid)
                prefs.set(array, forKey: keepConnectionArrayUDKey)
                NotificationCenter.default.post(name: .ConnectionPersistenceDidStartToKeepConnection,
                                                object: nil,
                                                userInfo: [ConnectionPersistenceDidStartToKeepConnectionKey.uuid: uuid,
                                                           ConnectionPersistenceDidStartToKeepConnectionKey.readRSSI: readRSSI(uuid: uuid)])
            }
        } else {
            if var array = prefs.array(forKey: keepConnectionArrayUDKey) as? [String] {
                if array.contains(uuid) {
                    array.removeAll(where: { $0 == uuid })
                    prefs.set(array, forKey: keepConnectionArrayUDKey)
                    NotificationCenter.default.post(name: .ConnectionPersistenceDidStopToKeepConnection,
                                                    object: nil,
                                                    userInfo: [ConnectionPersistenceDidStopToKeepConnectionKey.uuid: uuid,
                                                               ConnectionPersistenceDidStopToKeepConnectionKey.readRSSI: readRSSI(uuid: uuid)])
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

    func readRSSI(uuid: String) -> Bool {
        if let array = prefs.array(forKey: readRSSIArrayUDKey) as? [String] {
            return array.contains(uuid)
        } else {
            return false
        }
    }

    func setReadRSSI(_ value: Bool, uuid: String) {
        if value {
            if var array = prefs.array(forKey: readRSSIArrayUDKey) as? [String] {
                if !array.contains(uuid) {
                    array.append(uuid)
                    prefs.set(array, forKey: readRSSIArrayUDKey)
                    NotificationCenter.default.post(name: .ConnectionPersistenceDidStartReadingRSSI, object: nil, userInfo: [ConnectionPersistenceDidStartReadingRSSIKey.uuid: uuid])
                }
            } else {
                var array = [String]()
                array.append(uuid)
                prefs.set(array, forKey: readRSSIArrayUDKey)
                NotificationCenter.default.post(name: .ConnectionPersistenceDidStartReadingRSSI, object: nil, userInfo: [ConnectionPersistenceDidStartReadingRSSIKey.uuid: uuid])
            }
        } else {
            if var array = prefs.array(forKey: readRSSIArrayUDKey) as? [String] {
                if array.contains(uuid) {
                    array.removeAll(where: { $0 == uuid })
                    prefs.set(array, forKey: readRSSIArrayUDKey)
                    NotificationCenter.default.post(name: .ConnectionPersistenceDidStopReadingRSSI, object: nil, userInfo: [ConnectionPersistenceDidStopReadingRSSIKey.uuid: uuid])
                }
            }
        }
    }

    func readRSSIInterval(uuid: String) -> Int {
        return prefs.optionalInt(forKey: readRSSIIntervalUDKeyPrefix + uuid) ?? 5
    }

    func setReadRSSIInterval(_ value: Int, uuid: String) {
        prefs.set(value, forKey: readRSSIIntervalUDKeyPrefix + uuid)
        NotificationCenter.default.post(name: .ConnectionPersistenceDidChangeReadRSSIInterval,
                                        object: nil,
                                        userInfo: [ConnectionPersistenceDidChangeReadRSSIIntervalKey.uuid: uuid, ConnectionPersistenceDidChangeReadRSSIIntervalKey.interval: value])
    }

    func logSyncDate(uuid: String) -> Date? {
        return prefs.value(forKey: logSyncDateUDKeyPrefix + uuid) as? Date
    }

    func setLogSyncDate(_ value: Date?, uuid: String) {
        prefs.set(value, forKey: logSyncDateUDKeyPrefix + uuid)
    }
}
