import Foundation
import RuuviOntology

protocol IDPersistence {
    func mac(for luid: LocalIdentifier) -> MACIdentifier?
    func set(mac: MACIdentifier, for luid: LocalIdentifier)
}
