import Foundation
import RuuviOntology

public protocol RuuviLocalIDs {
    func mac(for luid: LocalIdentifier) -> MACIdentifier?
    func set(mac: MACIdentifier, for luid: LocalIdentifier)
}
