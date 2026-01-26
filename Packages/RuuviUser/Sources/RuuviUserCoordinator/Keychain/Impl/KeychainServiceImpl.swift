import Foundation
import KeychainAccess

final class KeychainServiceImpl: @unchecked Sendable {
    private let keychain: Keychain = .init(
        service: "com.ruuvi.station",
        accessGroup: "4MUYJ4YYH4.com.ruuvi.station"
    )
    .label("Ruuvi Station")
    .synchronizable(false)
    .accessibility(.afterFirstUnlockThisDeviceOnly)

    private enum Account: String {
        case ruuviUserApi
        case userApiEmail
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
