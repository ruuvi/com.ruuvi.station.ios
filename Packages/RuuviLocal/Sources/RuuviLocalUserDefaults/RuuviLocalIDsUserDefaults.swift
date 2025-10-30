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

    func fullMac(for mac: MACIdentifier) -> MACIdentifier? {
        let key = mac.value + ".full"
        if let value = UserDefaults.standard.string(forKey: key) {
            return value.mac
        }
        return nil
    }

    func originalMac(for fullMac: MACIdentifier) -> MACIdentifier? {
        let key = fullMac.value + ".orig"
        if let value = UserDefaults.standard.string(forKey: key) {
            return value.mac
        }
        return nil
    }

    func set(fullMac: MACIdentifier, for mac: MACIdentifier) {
        let key = mac.value + ".full"
        UserDefaults.standard.set(fullMac.value, forKey: key)

        let reverseKey = fullMac.value + ".orig"
        UserDefaults.standard.set(mac.value, forKey: reverseKey)
    }

    func removeFullMac(for mac: MACIdentifier) {
        let key = mac.value + ".full"
        if let full = UserDefaults.standard.string(forKey: key) {
            let reverseKey = full + ".orig"
            UserDefaults.standard.removeObject(forKey: reverseKey)
        }
        UserDefaults.standard.removeObject(forKey: key)
    }
}
