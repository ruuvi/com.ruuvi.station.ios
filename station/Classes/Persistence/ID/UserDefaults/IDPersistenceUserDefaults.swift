import Foundation

class IDPersistenceUserDefaults: IDPersistence {
    func mac(for luid: LocalIdentifier) -> MACIdentifier? {
        return UserDefaults.standard.string(forKey: luid.value)?.mac
    }

    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        UserDefaults.standard.set(mac.value, forKey: luid.value)
    }
}
