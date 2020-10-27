import Foundation
import KeychainAccess

class KeychainServiceImpl {
    private let keychain: Keychain = Keychain(service: "com.ruuvi.station",
                                              accessGroup: "4MUYJ4YYH4.com.ruuvi.station")
        .label("Ruuvi Station")
        .synchronizable(true)
        .accessibility(.whenPasscodeSetThisDeviceOnly)

    private enum Account: String {
        case kaltiot
        case ruuviUserApi
    }
}
// MARK: - Public
extension KeychainServiceImpl: KeychainService {
    var kaltiotApiKey: String? {
        get {
            return keychain[Account.kaltiot.rawValue]
        }
        set {
            if let value = newValue {
                keychain[Account.kaltiot.rawValue] = value
            } else {
                try? keychain.remove(
                    Account.kaltiot.rawValue,
                    ignoringAttributeSynchronizable: true
                )
            }
        }
    }

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
}
