import Foundation
import RuuviLocal
import RuuviOntology

class RuuviLocalIDsUserDefaults: RuuviLocalIDs {
    func mac(for luid: LocalIdentifier) -> MACIdentifier? {
        UserDefaults.standard.string(forKey: luid.value)?.mac
    }

    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        UserDefaults.standard.set(mac.value, forKey: luid.value)
    }

    func luid(for mac: MACIdentifier) -> LocalIdentifier? {
        UserDefaults.standard.string(forKey: mac.value)?.luid
    }

    func set(luid: LocalIdentifier, for mac: MACIdentifier) {
        UserDefaults.standard.set(luid.value, forKey: mac.value)
    }

    func clear(sensor: RuuviTagSensor) {
        if let luid = sensor.luid {
            UserDefaults.standard.set(nil, forKey: luid.value)
        }
        if let macId = sensor.macId {
            UserDefaults.standard.set(nil, forKey: macId.value)
        }
    }
}
