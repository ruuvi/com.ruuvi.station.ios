#if SWIFT_PACKAGE
    import RuuviLocal
#endif
import Foundation
import RuuviOntology

final class RuuviLocalConnectionsUserDefaults: RuuviLocalConnections {
    private let prefs: UserDefaults
    private let notifications: NotificationCenter
    private let keepConnectionArrayUDKey = "ConnectionPersistenceUserDefaults.keepConnection.array"

    init(defaults: UserDefaults = .standard, notifications: NotificationCenter = .default) {
        prefs = defaults
        self.notifications = notifications
    }

    var keepConnectionUUIDs: [AnyLocalIdentifier] {
        storedUUIDs.map(\.luid.any)
    }

    private var storedUUIDs: [String] {
        prefs.array(forKey: keepConnectionArrayUDKey) as? [String] ?? []
    }

    func keepConnection(to luid: LocalIdentifier) -> Bool {
        storedUUIDs.contains(luid.value)
    }

    func setKeepConnection(_ value: Bool, for luid: LocalIdentifier) {
        let uuid = luid.value
        var identifiers = storedUUIDs
        guard identifiers.contains(uuid) != value else { return }
        if value { identifiers.append(uuid) } else { identifiers.removeAll { $0 == uuid } }
        prefs.set(identifiers, forKey: keepConnectionArrayUDKey)
        if value {
            notifications.post(
                name: .ConnectionPersistenceDidStartToKeepConnection, object: nil,
                userInfo: [CPDidStartToKeepConnectionKey.uuid: uuid])
        } else {
            notifications.post(
                name: .ConnectionPersistenceDidStopToKeepConnection, object: nil,
                userInfo: [CPDidStopToKeepConnectionKey.uuid: uuid])
        }
    }

    func unpairAllConnection() {
        let identifiers = storedUUIDs
        prefs.set([String](), forKey: keepConnectionArrayUDKey)
        for uuid in identifiers {
            notifications.post(
                name: .ConnectionPersistenceDidStopToKeepConnection, object: nil,
                userInfo: [CPDidStopToKeepConnectionKey.uuid: uuid])
        }
    }
}
