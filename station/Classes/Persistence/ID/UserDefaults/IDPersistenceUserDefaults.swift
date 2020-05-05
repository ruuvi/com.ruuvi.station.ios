import Foundation

class IDPersistenceUserDefaults: IDPersistence {
    func mac(for luid: LocalIdentifier) -> String? {
        return UserDefaults.standard.string(forKey: luid.value)
    }

    func set(mac: String, for luid: LocalIdentifier) {
        UserDefaults.standard.set(mac, forKey: luid.value)
    }
}
