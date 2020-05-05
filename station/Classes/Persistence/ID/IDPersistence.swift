import Foundation

protocol IDPersistence {
    func mac(for luid: LocalIdentifier) -> String?
    func set(mac: String, for luid: LocalIdentifier)
}
