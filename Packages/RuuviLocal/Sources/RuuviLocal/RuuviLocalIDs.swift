import Foundation
import RuuviOntology

public protocol RuuviLocalIDs {
    func mac(for luid: LocalIdentifier) -> MACIdentifier?
    func set(mac: MACIdentifier, for luid: LocalIdentifier)
    func luid(for mac: MACIdentifier) -> LocalIdentifier?
    func extendedLuid(for mac: MACIdentifier) -> LocalIdentifier?
    func set(luid: LocalIdentifier, for mac: MACIdentifier)
    func set(extendedLuid: LocalIdentifier, for mac: MACIdentifier)

    func fullMac(for mac: MACIdentifier) -> MACIdentifier?
    func originalMac(for fullMac: MACIdentifier) -> MACIdentifier?
    func set(fullMac: MACIdentifier, for mac: MACIdentifier)
    func removeFullMac(for mac: MACIdentifier)
}
