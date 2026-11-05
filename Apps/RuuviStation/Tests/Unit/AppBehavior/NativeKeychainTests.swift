import Foundation
import Security
@testable import RuuviUser
import XCTest

final class NativeKeychainTests: XCTestCase {
    func testExistingKeychainItemCanBeReadUpdatedAndDeletedWithoutChangingItsProtection() throws {
        let serviceName = "com.ruuvi.station.tests." + UUID().uuidString
        let service = KeychainServiceImpl(service: serviceName, accessGroup: nil)
        defer {
            service.ruuviUserApiKey = nil
            service.userApiEmail = nil
        }
        let legacy: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "ruuviUserApi",
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
            kSecAttrLabel as String: "Ruuvi Station",
            kSecValueData as String: Data("existing-token".utf8),
        ]
        XCTAssertEqual(SecItemAdd(legacy as CFDictionary, nil), errSecSuccess)
        XCTAssertEqual(service.ruuviUserApiKey, "existing-token")
        XCTAssertTrue(service.userIsAuthorized)
        service.ruuviUserApiKey = "updated-token"
        service.userApiEmail = "tést@example.com"
        XCTAssertEqual(service.ruuviUserApiKey, "updated-token")
        XCTAssertEqual(service.userApiEmail, "tést@example.com")
        var result: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        let items = try XCTUnwrap(result as? [[String: Any]])
        XCTAssertEqual(items.count, 2)
        for item in items {
            XCTAssertEqual(
                item[kSecAttrAccessible as String] as? String,
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
            XCTAssertEqual(item[kSecAttrSynchronizable as String] as? Bool, false)
        }
        service.ruuviUserApiKey = nil
        XCTAssertNil(service.ruuviUserApiKey)
        XCTAssertFalse(service.userIsAuthorized)
        XCTAssertEqual(service.userApiEmail, "tést@example.com")
        service.userApiEmail = nil
        XCTAssertNil(service.userApiEmail)
    }
}
