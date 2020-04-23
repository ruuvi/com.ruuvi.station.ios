//
//  KeychainServiceImpl.swift
//  station
//
//  Created by Viik.ufa on 23.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

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
    }
}
//MARK: - Public
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
}
