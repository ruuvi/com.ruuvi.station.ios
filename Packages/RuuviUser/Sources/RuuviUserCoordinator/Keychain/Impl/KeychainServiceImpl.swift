import Foundation
import KeychainAccess

final class KeychainServiceImpl {
    private let keychain: Keychain = Keychain(
        service: "com.ruuvi.station",
        accessGroup: "4MUYJ4YYH4.com.ruuvi.station"
    )
    .label("Ruuvi Station")
    .synchronizable(true)
    .accessibility(.afterFirstUnlock)

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
                return UserDefaults.standard
                    .string(forKey: Account.ruuviUserApi.rawValue)
            }
        }
        set {
            if let value = newValue {
                do {
                    try keychain.set(value, key: Account.ruuviUserApi.rawValue)
                } catch {
                    UserDefaults.standard
                        .setValue(value, forKey: Account.ruuviUserApi.rawValue)
                }
            } else {
                do {
                    try keychain.remove(Account.ruuviUserApi.rawValue)
                } catch {
                    UserDefaults.standard
                        .removeObject(forKey: Account.ruuviUserApi.rawValue)
                }
            }
        }
    }

    var userApiEmail: String? {
        get {
            do {
                return try keychain.get(Account.userApiEmail.rawValue)
            } catch {
                return UserDefaults.standard
                    .string(forKey: Account.userApiEmail.rawValue)
            }
        }
        set {
            if let value = newValue {
                do {
                    try keychain.set(value, key: Account.userApiEmail.rawValue)
                } catch {
                    UserDefaults.standard
                        .setValue(value, forKey: Account.userApiEmail.rawValue)
                }
            } else {
                do {
                    try keychain.remove(Account.userApiEmail.rawValue)
                } catch {
                    UserDefaults.standard
                        .removeObject(forKey: Account.userApiEmail.rawValue)
                }
            }
        }
    }

    var userIsAuthorized: Bool {
        return !((ruuviUserApiKey ?? "").isEmpty)
            && !((userApiEmail ?? "").isEmpty)
    }
}
