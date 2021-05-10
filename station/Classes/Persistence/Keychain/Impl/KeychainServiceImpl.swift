import Foundation
import KeychainAccess

class KeychainServiceImpl {
    var settings: Settings!

    private let keychain: Keychain = Keychain(service: "com.ruuvi.station",
                                              accessGroup: "4MUYJ4YYH4.com.ruuvi.station")
        .label("Ruuvi Station")
        .synchronizable(true)
        .accessibility(.whenPasscodeSetThisDeviceOnly)

    private enum Account: String {
        case ruuviUserApi
        case userApiEmail
    }
}
// MARK: - Public
extension KeychainServiceImpl: KeychainService {
    var ruuviUserApiKey: String? {
        get {
            return keychain[Account.ruuviUserApi.rawValue]
        }
        set {
            if let value = newValue {
                keychain[Account.ruuviUserApi.rawValue] = value
            } else {
                try? keychain.remove(
                    Account.ruuviUserApi.rawValue,
                    ignoringAttributeSynchronizable: true
                )
            }
        }
    }

    var userApiEmail: String? {
        get {
            return keychain[Account.userApiEmail.rawValue]
        }
        set {
            if let value = newValue {
                keychain[Account.userApiEmail.rawValue] = value
            } else {
                try? keychain.remove(
                    Account.userApiEmail.rawValue,
                    ignoringAttributeSynchronizable: true
                )
            }
        }
    }

    var userIsAuthorized: Bool {
        return !((ruuviUserApiKey ?? "").isEmpty)
            && !((userApiEmail ?? "").isEmpty)
            && settings.networkFeatureEnabled
    }
}
