import Foundation
import RuuviOntology

class RuuviLocalIDsUserDefaults: RuuviLocalIDs {
    func mac(for luid: LocalIdentifier) -> MACIdentifier? {
        return UserDefaults.standard.string(forKey: luid.value)?.mac
    }

    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        UserDefaults.standard.set(mac.value, forKey: luid.value)
    }

    func luid(for mac: MACIdentifier) -> LocalIdentifier? {
        return UserDefaults.standard.string(forKey: mac.value)?.luid
    }

    func set(luid: LocalIdentifier, for mac: MACIdentifier) {
        UserDefaults.standard.set(luid.value, forKey: mac.value)
    }
}
