import Foundation
import RuuviOntology

class RuuviLocalIDsUserDefaults: RuuviLocalIDs {
    func mac(for luid: LocalIdentifier) -> MACIdentifier? {
        UserDefaults.standard.string(forKey: luid.value)?.mac
    }

    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        UserDefaults.standard.set(mac.value, forKey: luid.value)
    }

    func extendedLuid(for mac: MACIdentifier) -> LocalIdentifier? {
        let key = mac.value + ".ext"
        return UserDefaults.standard.string(forKey: key)?.luid
    }

    func luid(for mac: MACIdentifier) -> LocalIdentifier? {
        UserDefaults.standard.string(forKey: mac.value)?.luid
    }

    func set(luid: LocalIdentifier, for mac: MACIdentifier) {
        UserDefaults.standard.set(luid.value, forKey: mac.value)
    }

    func set(extendedLuid: LocalIdentifier, for mac: MACIdentifier) {
        let key = mac.value + ".ext"
        UserDefaults.standard.set(extendedLuid.value, forKey: key)
    }
}
