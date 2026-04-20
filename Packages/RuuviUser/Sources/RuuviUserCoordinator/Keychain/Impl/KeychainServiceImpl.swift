import Foundation
import KeychainAccess

protocol KeychainStore {
    func get(_ key: String) throws -> String?
    func set(_ value: String, key: String) throws
    func remove(_ key: String) throws
}

extension Keychain: KeychainStore {
    func get(_ key: String) throws -> String? { try get(key, ignoringAttributeSynchronizable: true) }

    func set(_ value: String, key: String) throws { try set(value, key: key, ignoringAttributeSynchronizable: true) }

    func remove(_ key: String) throws { try remove(key, ignoringAttributeSynchronizable: true) }
}

final class KeychainServiceImpl {
    private let keychain: any KeychainStore

    init(
        keychain: any KeychainStore = KeychainServiceImpl.makeDefaultKeychain()
    ) {
        self.keychain = keychain
    }

    private enum Account: String {
        case ruuviUserApi
        case userApiEmail
    }

    private static func makeDefaultKeychain() -> any KeychainStore {
        Keychain(
            service: "com.ruuvi.station",
            accessGroup: "4MUYJ4YYH4.com.ruuvi.station"
        )
        .label("Ruuvi Station")
        .synchronizable(false)
        .accessibility(.afterFirstUnlockThisDeviceOnly)
    }
}

// MARK: - Public

extension KeychainServiceImpl: KeychainService {
    var ruuviUserApiKey: String? {
        get {
            do {
                return try keychain.get(Account.ruuviUserApi.rawValue)
            } catch {
                return nil
            }
        }
        set {
            if let value = newValue {
                do {
                    try keychain.set(value, key: Account.ruuviUserApi.rawValue)
                } catch {
                    // No op.
                }
            } else {
                do {
                    try keychain.remove(Account.ruuviUserApi.rawValue)
                } catch {
                    // No op.
                }
            }
        }
    }

    var userApiEmail: String? {
        get {
            do {
                return try keychain.get(Account.userApiEmail.rawValue)
            } catch {
                return nil
            }
        }
        set {
            if let value = newValue {
                do {
                    try keychain.set(value, key: Account.userApiEmail.rawValue)
                } catch {
                    // No op.
                }
            } else {
                do {
                    try keychain.remove(Account.userApiEmail.rawValue)
                } catch {
                    // No op.
                }
            }
        }
    }

    var userIsAuthorized: Bool {
        ruuviUserApiKey?.isEmpty == false
    }
}
