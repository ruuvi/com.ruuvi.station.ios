import Foundation

class IDPersistenceUserDefaults: IDPersistence {
    func mac(for uuid: String) -> String? {
        return UserDefaults.standard.string(forKey: uuid)
    }

    func set(mac: String, for uuid: String) {
        UserDefaults.standard.set(mac, forKey: uuid)
    }
}
