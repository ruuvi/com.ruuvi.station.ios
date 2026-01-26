import Foundation
import RuuviOntology

public protocol RuuviLocalIDs: Sendable {
    func mac(for luid: LocalIdentifier) async -> MACIdentifier?
    func set(mac: MACIdentifier, for luid: LocalIdentifier) async
    func luid(for mac: MACIdentifier) async -> LocalIdentifier?
    func extendedLuid(for mac: MACIdentifier) async -> LocalIdentifier?
    func set(luid: LocalIdentifier, for mac: MACIdentifier) async
    func set(extendedLuid: LocalIdentifier, for mac: MACIdentifier) async

    func fullMac(for mac: MACIdentifier) async -> MACIdentifier?
    func originalMac(for fullMac: MACIdentifier) async -> MACIdentifier?
    func set(fullMac: MACIdentifier, for mac: MACIdentifier) async
    func removeFullMac(for mac: MACIdentifier) async
}
