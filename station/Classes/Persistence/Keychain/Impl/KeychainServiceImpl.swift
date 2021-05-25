import Foundation
import KeychainAccess

class KeychainServiceImpl {
    var settings: Settings!

    private let keychain: Keychain = Keychain(service: "com.ruuvi.station",
                                              accessGroup: "4MUYJ4YYH4.com.ruuvi.station")
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
            if Bundle.main.isRuuvi {
                return keychain[Account.ruuviUserApi.rawValue]
            } else {
                return UserDefaults.standard
                    .string(forKey: Account.ruuviUserApi.rawValue)
            }
        }
        set {
            if let value = newValue {
                if Bundle.main.isRuuvi {
                    keychain[Account.ruuviUserApi.rawValue] = value
                } else {
                    UserDefaults.standard
                        .setValue(value, forKey: Account.ruuviUserApi.rawValue)
                }
            } else {
                if Bundle.main.isRuuvi {
                    try? keychain.remove(
                        Account.ruuviUserApi.rawValue,
                        ignoringAttributeSynchronizable: true
                    )
                } else {
                    UserDefaults.standard
                        .removeObject(forKey: Account.ruuviUserApi.rawValue)
                }
            }
        }
    }

    var userApiEmail: String? {
        get {
            if Bundle.main.isRuuvi {
                return keychain[Account.userApiEmail.rawValue]
            } else {
                return UserDefaults.standard
                    .string(forKey: Account.userApiEmail.rawValue)
            }
        }
        set {
            if let value = newValue {
                if Bundle.main.isRuuvi {
                    keychain[Account.userApiEmail.rawValue] = value
                } else {
                    UserDefaults.standard
                        .set(value, forKey: Account.userApiEmail.rawValue)
                }
            } else {
                if Bundle.main.isRuuvi {
                    try? keychain.remove(
                        Account.userApiEmail.rawValue,
                        ignoringAttributeSynchronizable: true
                    )
                } else {
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
