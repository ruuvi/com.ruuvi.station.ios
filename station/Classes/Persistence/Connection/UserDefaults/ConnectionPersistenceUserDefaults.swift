import Foundation

class ConnectionPersistenceUserDefaults: ConnectionPersistence {

    private let prefs = UserDefaults.standard
    private let keepConnectionArrayUDKey = "ConnectionPersistenceUserDefaults.keepConnection.array"

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

    func setKeepConnection(_ value: Bool, for uuid: String) {
        if value {
            if var array = prefs.array(forKey: keepConnectionArrayUDKey) as? [String],
                !array.contains(uuid) {
                array.append(uuid)
                prefs.set(array, forKey: keepConnectionArrayUDKey)
                NotificationCenter.default.post(name: .ConnectionPersistenceDidStartToKeepConnection,
                                                object: nil,
                                                userInfo:
                    [CPDidStartToKeepConnectionKey.uuid: uuid])
            } else {
                var array = [String]()
                array.append(uuid)
                prefs.set(array, forKey: keepConnectionArrayUDKey)
                NotificationCenter.default.post(name: .ConnectionPersistenceDidStartToKeepConnection,
                                                object: nil,
                                                userInfo:
                    [CPDidStartToKeepConnectionKey.uuid: uuid])
            }
        } else {
            if var array = prefs.array(forKey: keepConnectionArrayUDKey) as? [String],
                array.contains(uuid) {
                array.removeAll(where: { $0 == uuid })
                prefs.set(array, forKey: keepConnectionArrayUDKey)
                NotificationCenter.default.post(name: .ConnectionPersistenceDidStopToKeepConnection,
                                                object: nil,
                                                userInfo:
                    [CPDidStopToKeepConnectionKey.uuid: uuid])
            }
        }
    }
}
