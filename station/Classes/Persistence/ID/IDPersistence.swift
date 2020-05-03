import Foundation

protocol IDPersistence {
    func mac(for uuid: String) -> String?
    func set(mac: String, for uuid: String)
}
