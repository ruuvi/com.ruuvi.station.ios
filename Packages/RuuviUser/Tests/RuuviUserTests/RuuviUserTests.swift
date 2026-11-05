import Foundation
import Security
import RuuviUser
#if SWIFT_PACKAGE
    @testable import RuuviUserCoordinator
#else
    @testable import RuuviUser
#endif
import XCTest

final class RuuviUserTests: XCTestCase {
    func testLoginPersistsCredentialsAndBothAuthorizationFlagsBeforeBroadcasting() {
        let fixture = UserFixture()
        defer { fixture.close() }
        var notifications = 0
        let observer = fixture.center.addObserver(forName: .RuuviUserDidAuthorized, object: nil, queue: nil) { note in
            notifications += 1
            XCTAssertTrue(note.object as? RuuviUserCoordinator === fixture.user)
            XCTAssertEqual(fixture.user.apiKey, "test-token")
            XCTAssertTrue(fixture.user.isAuthorized)
            XCTAssertTrue(fixture.widgetDefaults.bool(forKey: fixture.authorizationKey))
        }
        defer { fixture.center.removeObserver(observer) }
        fixture.user.email = "User@EXAMPLE.com"
        fixture.user.login(apiKey: "test-token")
        XCTAssertEqual(fixture.keychain.userApiEmail, "user@example.com")
        XCTAssertEqual(notifications, 1)
        fixture.user.logout()
        XCTAssertNil(fixture.user.apiKey)
        XCTAssertNil(fixture.user.email)
        XCTAssertFalse(fixture.user.isAuthorized)
        XCTAssertFalse(fixture.widgetDefaults.bool(forKey: fixture.authorizationKey))
        XCTAssertFalse(fixture.defaults.bool(forKey: fixture.authorizationKey))
        XCTAssertEqual(notifications, 1)
    }

    func testCredentialsAloneDoNotRestoreAuthorizationAfterAnAppReinstall() {
        let fixture = UserFixture()
        defer { fixture.close() }
        fixture.keychain.storedKey = "old-keychain-token"
        fixture.keychain.userApiEmail = "LEGACY@Example.COM"
        XCTAssertFalse(fixture.user.isAuthorized)
        XCTAssertEqual(fixture.user.email, "legacy@example.com")
        fixture.defaults.set(true, forKey: fixture.authorizationKey)
        XCTAssertTrue(fixture.user.isAuthorized)
        fixture.keychain.storedKey = nil
        XCTAssertFalse(fixture.user.isAuthorized)
        fixture.keychain.storedKey = ""
        XCTAssertFalse(fixture.user.isAuthorized)
    }

    func testEmptyOrFailedCredentialWritesCannotPublishSuccessfulAuthorization() {
        let fixture = UserFixture()
        defer { fixture.close() }
        var notifications = 0
        let observer = fixture.center.addObserver(forName: .RuuviUserDidAuthorized, object: nil, queue: nil) { _ in
            notifications += 1
        }
        defer { fixture.center.removeObserver(observer) }
        fixture.user.login(apiKey: "")
        XCTAssertFalse(fixture.user.isAuthorized)
        XCTAssertFalse(fixture.widgetDefaults.bool(forKey: fixture.authorizationKey))
        XCTAssertEqual(notifications, 0)
        fixture.keychain.storedKey = "previous-token"
        fixture.keychain.rejectWrites = true
        fixture.user.login(apiKey: "new-token")
        XCTAssertFalse(fixture.user.isAuthorized)
        XCTAssertFalse(fixture.widgetDefaults.bool(forKey: fixture.authorizationKey))
        XCTAssertEqual(fixture.keychain.storedKey, "previous-token")
        XCTAssertEqual(notifications, 0)
        fixture.user.logout()
        XCTAssertFalse(fixture.user.isAuthorized)
    }

    func testAuthorizationStillWorksWhenTheWidgetSuiteIsUnavailable() {
        let fixture = UserFixture()
        defer { fixture.close() }
        let user = RuuviUserCoordinator(
            keychainService: fixture.keychain, defaults: fixture.defaults,
            appGroupDefaults: nil, notificationCenter: fixture.center)
        user.login(apiKey: "token")
        XCTAssertTrue(user.isAuthorized)
        user.logout()
        XCTAssertFalse(user.isAuthorized)
    }
}

final class KeychainServiceTests: XCTestCase {
    func testReadsUseExistingAccountServiceAccessGroupAndUTF8Representation() {
        let fake = FakeKeychainClient()
        fake.result = (errSecSuccess, Data("tøkén".utf8) as NSData)
        let service = KeychainServiceImpl(client: fake.client)
        XCTAssertEqual(service.ruuviUserApiKey, "tøkén")
        XCTAssertTrue(service.userIsAuthorized)
        XCTAssertEqual(service.userApiEmail, "tøkén")
        XCTAssertEqual(
            fake.queries.map { $0[kSecAttrAccount as String] as? String },
            ["ruuviUserApi", "ruuviUserApi", "userApiEmail"])
        for query in fake.queries {
            XCTAssertEqual(query[kSecAttrService as String] as? String, "com.ruuvi.station")
            XCTAssertEqual(query[kSecAttrAccessGroup as String] as? String, "4MUYJ4YYH4.com.ruuvi.station")
            XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
            XCTAssertEqual(query[kSecMatchLimit as String] as? String, kSecMatchLimitOne as String)
            XCTAssertEqual(query[kSecReturnData as String] as? Bool, true)
        }
    }

    func testUnavailableInvalidOrEmptyCredentialsNeverAuthorize() {
        let fake = FakeKeychainClient()
        let service = KeychainServiceImpl(client: fake.client)
        for result: (OSStatus, AnyObject?) in [
            (errSecItemNotFound, nil), (errSecInteractionNotAllowed, Data("cached".utf8) as NSData),
            (errSecSuccess, nil), (errSecSuccess, "wrong type" as NSString),
            (errSecSuccess, Data([0xFF]) as NSData),
        ] {
            fake.result = result
            XCTAssertNil(service.ruuviUserApiKey)
            XCTAssertNil(service.userApiEmail)
            XCTAssertFalse(service.userIsAuthorized)
        }
        fake.result = (errSecSuccess, Data() as NSData)
        XCTAssertEqual(service.ruuviUserApiKey, "")
        XCTAssertFalse(service.userIsAuthorized)
    }

    func testWritesUpdateInPlaceOrAddWithTheExistingProtectionAndDoNotDeleteOnFailure() {
        let fake = FakeKeychainClient()
        let service = KeychainServiceImpl(client: fake.client)
        service.ruuviUserApiKey = "first"
        XCTAssertEqual(fake.updates.count, 1)
        XCTAssertTrue(fake.adds.isEmpty)
        fake.updateStatus = errSecItemNotFound
        service.userApiEmail = "user@example.com"
        XCTAssertEqual(fake.adds.count, 1)
        let attributes = fake.adds[0]
        XCTAssertEqual(attributes[kSecValueData as String] as? Data, Data("user@example.com".utf8))
        XCTAssertEqual(attributes[kSecAttrAccount as String] as? String, "userApiEmail")
        XCTAssertEqual(attributes[kSecAttrService as String] as? String, "com.ruuvi.station")
        XCTAssertEqual(attributes[kSecAttrAccessGroup as String] as? String, "4MUYJ4YYH4.com.ruuvi.station")
        XCTAssertEqual(attributes[kSecAttrSynchronizable as String] as? Bool, false)
        XCTAssertEqual(attributes[kSecAttrLabel as String] as? String, "Ruuvi Station")
        XCTAssertEqual(
            attributes[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        fake.updateStatus = errSecInteractionNotAllowed
        service.ruuviUserApiKey = "locked"
        XCTAssertEqual(fake.adds.count, 1)
        XCTAssertTrue(fake.deletes.isEmpty)
    }

    func testConcurrentInsertRetriesAnUpdateAndNilDeletesOnlyTheSelectedAccount() {
        let fake = FakeKeychainClient()
        fake.updateStatus = errSecItemNotFound
        fake.addStatus = errSecDuplicateItem
        let service = KeychainServiceImpl(service: "isolated", accessGroup: nil, client: fake.client)
        service.ruuviUserApiKey = "winner"
        XCTAssertEqual(fake.updates.count, 2)
        XCTAssertEqual(fake.adds.count, 1)
        XCTAssertEqual(fake.updates.last?.1[kSecValueData as String] as? Data, Data("winner".utf8))
        service.ruuviUserApiKey = nil
        service.userApiEmail = nil
        XCTAssertEqual(fake.deletes.map { $0[kSecAttrAccount as String] as? String }, ["ruuviUserApi", "userApiEmail"])
        XCTAssertTrue(fake.deletes.allSatisfy { $0[kSecAttrService as String] as? String == "isolated" })
        XCTAssertTrue(fake.deletes.allSatisfy { $0[kSecAttrAccessGroup as String] == nil })
    }
}

private final class FakeKeychainClient {
    var result: (OSStatus, AnyObject?) = (errSecItemNotFound, nil)
    var updateStatus = errSecSuccess
    var addStatus = errSecSuccess
    var queries = [[String: Any]]()
    var updates = [([String: Any], [String: Any])]()
    var adds = [[String: Any]]()
    var deletes = [[String: Any]]()
    var client: KeychainClient {
        .init(
            copyMatching: {
                self.queries.append($0); return self.result
            },
            update: {
                self.updates.append(($0, $1)); return self.updateStatus
            },
            add: {
                self.adds.append($0); return self.addStatus
            },
            delete: {
                self.deletes.append($0); return errSecSuccess
            })
    }
}

private final class UserFixture {
    let defaultsName = "RuuviUserTests." + UUID().uuidString
    let widgetName = "RuuviUserWidgetTests." + UUID().uuidString
    let defaults: UserDefaults
    let widgetDefaults: UserDefaults
    let keychain = UserKeychain()
    let center = NotificationCenter()
    let user: RuuviUserCoordinator
    let authorizationKey = "RuuviUserCoordinator.isAuthorizedUDKey"

    init() {
        defaults = UserDefaults(suiteName: defaultsName)!
        widgetDefaults = UserDefaults(suiteName: widgetName)!
        user = RuuviUserCoordinator(
            keychainService: keychain, defaults: defaults,
            appGroupDefaults: widgetDefaults, notificationCenter: center)
    }
    func close() {
        defaults.removePersistentDomain(forName: defaultsName)
        widgetDefaults.removePersistentDomain(forName: widgetName)
    }
}

private final class UserKeychain: KeychainService {
    var storedKey: String?
    var rejectWrites = false
    var ruuviUserApiKey: String? {
        get { storedKey }
        set { if !rejectWrites { storedKey = newValue } }
    }
    var userApiEmail: String?
    var userIsAuthorized: Bool { storedKey?.isEmpty == false }
}
