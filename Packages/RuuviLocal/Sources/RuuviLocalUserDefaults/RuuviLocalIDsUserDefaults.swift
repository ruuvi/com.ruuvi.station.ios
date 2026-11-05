#if SWIFT_PACKAGE
    import RuuviLocal
#endif
import Foundation
import RuuviOntology

class RuuviLocalIDsUserDefaults: RuuviLocalIDs {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func mac(for luid: LocalIdentifier) -> MACIdentifier? {
        defaults.string(forKey: luid.value)?.mac
    }

    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        defaults.set(mac.value, forKey: luid.value)
    }

    func extendedLuid(for mac: MACIdentifier) -> LocalIdentifier? {
        let key = mac.value + ".ext"
        return defaults.string(forKey: key)?.luid
    }

    func luid(for mac: MACIdentifier) -> LocalIdentifier? {
        defaults.string(forKey: mac.value)?.luid
    }

    func set(luid: LocalIdentifier, for mac: MACIdentifier) {
        defaults.set(luid.value, forKey: mac.value)
    }

    func set(extendedLuid: LocalIdentifier, for mac: MACIdentifier) {
        let key = mac.value + ".ext"
        defaults.set(extendedLuid.value, forKey: key)
    }

    func fullMac(for mac: MACIdentifier) -> MACIdentifier? {
        let key = mac.value + ".full"
        if let value = defaults.string(forKey: key) {
            return value.mac
        }
        return nil
    }

    func originalMac(for fullMac: MACIdentifier) -> MACIdentifier? {
        let key = fullMac.value + ".orig"
        if let value = defaults.string(forKey: key) {
            return value.mac
        }
        return nil
    }

    func set(fullMac: MACIdentifier, for mac: MACIdentifier) {
        removeFullMac(for: mac)
        if let previous = originalMac(for: fullMac), self.fullMac(for: previous)?.value == fullMac.value {
            defaults.removeObject(forKey: previous.value + ".full")
        }
        let key = mac.value + ".full"
        defaults.set(fullMac.value, forKey: key)

        let reverseKey = fullMac.value + ".orig"
        defaults.set(mac.value, forKey: reverseKey)
    }

    func removeFullMac(for mac: MACIdentifier) {
        let key = mac.value + ".full"
        if let full = defaults.string(forKey: key), defaults.string(forKey: full + ".orig") == mac.value {
            let reverseKey = full + ".orig"
            defaults.removeObject(forKey: reverseKey)
        }
        defaults.removeObject(forKey: key)
    }
}
