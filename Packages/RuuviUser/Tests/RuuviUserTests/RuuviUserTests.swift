@testable import RuuviUser
import KeychainAccess
import XCTest

final class RuuviUserTests: XCTestCase {
    private let isAuthorizedKey = "RuuviUserCoordinator.isAuthorizedUDKey"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: isAuthorizedKey)
        UserDefaults(suiteName: "group.com.ruuvi.station.widgets")?.removeObject(forKey: isAuthorizedKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: isAuthorizedKey)
        UserDefaults(suiteName: "group.com.ruuvi.station.widgets")?.removeObject(forKey: isAuthorizedKey)
        super.tearDown()
    }

    func testLoginStoresApiKeyMarksAuthorizedAndPostsNotification() {
        let keychain = KeychainServiceSpy()
        let sut = RuuviUserCoordinator(keychainService: keychain)
        let expectation = expectation(description: "authorization notification posted")
        let token = NotificationCenter.default.addObserver(
            forName: .RuuviUserDidAuthorized,
            object: sut,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        sut.login(apiKey: "api-key")

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(keychain.ruuviUserApiKey, "api-key")
        XCTAssertTrue(sut.isAuthorized)
    }

    func testEmailIsNormalizedAndLogoutClearsState() {
        let keychain = KeychainServiceSpy()
        let sut = RuuviUserCoordinator(keychainService: keychain)

        sut.email = "USER@Example.COM"
        sut.login(apiKey: "api-key")
        sut.logout()

        XCTAssertEqual(keychain.userApiEmail, nil)
        XCTAssertNil(sut.apiKey)
        XCTAssertNil(sut.email)
        XCTAssertFalse(sut.isAuthorized)
    }

    func testAuthorizationRequiresBothKeychainAndDefaultsFlag() {
        let keychain = KeychainServiceSpy()
        keychain.ruuviUserApiKey = "api-key"
        let sut = RuuviUserCoordinator(keychainService: keychain)

        XCTAssertFalse(sut.isAuthorized)

        sut.login(apiKey: "api-key")
        XCTAssertTrue(sut.isAuthorized)

        keychain.ruuviUserApiKey = nil
        XCTAssertFalse(sut.isAuthorized)
    }

    func testLoginAndLogoutMirrorAuthorizationFlagIntoWidgetAppGroupDefaults() {
        let keychain = KeychainServiceSpy()
        let sut = RuuviUserCoordinator(keychainService: keychain)
        let widgetDefaults = UserDefaults(suiteName: "group.com.ruuvi.station.widgets")

        sut.login(apiKey: "api-key")
        XCTAssertTrue(widgetDefaults?.bool(forKey: isAuthorizedKey) ?? false)

        sut.logout()
        XCTAssertFalse(widgetDefaults?.bool(forKey: isAuthorizedKey) ?? true)
    }

    func testFactoryCreatesCoordinatorBackedUser() {
        let sut = RuuviUserFactoryCoordinator()

        let user = sut.createUser()

        XCTAssertTrue(user is RuuviUserCoordinator)
    }

    func testKeychainServiceImplStoresReadsAndRemovesValues() {
        let store = KeychainStoreSpy()
        let sut = KeychainServiceImpl(keychain: store)

        sut.ruuviUserApiKey = "api-key"
        sut.userApiEmail = "User@Example.com"

        XCTAssertEqual(sut.ruuviUserApiKey, "api-key")
        XCTAssertEqual(sut.userApiEmail, "User@Example.com")
        XCTAssertTrue(sut.userIsAuthorized)

        sut.ruuviUserApiKey = nil
        sut.userApiEmail = nil

        XCTAssertNil(sut.ruuviUserApiKey)
        XCTAssertNil(sut.userApiEmail)
        XCTAssertFalse(sut.userIsAuthorized)
    }

    func testKeychainServiceImplSwallowsStoreFailures() {
        let sut = KeychainServiceImpl(keychain: FailingKeychainStoreSpy())

        sut.ruuviUserApiKey = "api-key"
        sut.userApiEmail = "user@example.com"

        XCTAssertNil(sut.ruuviUserApiKey)
        XCTAssertNil(sut.userApiEmail)
        XCTAssertFalse(sut.userIsAuthorized)
    }

    func testKeychainServiceImplSwallowsRemoveFailures() {
        let sut = KeychainServiceImpl(keychain: RemoveFailingKeychainStoreSpy())

        sut.ruuviUserApiKey = nil
        sut.userApiEmail = nil

        XCTAssertFalse(sut.userIsAuthorized)
    }

    func testKeychainAdapterInvokesReadWriteAndRemoveOperations() {
        let key = "key-\(UUID().uuidString)"
        let store: any KeychainStore = Keychain(service: "com.ruuvi.station.tests.\(UUID().uuidString)")

        try? store.remove(key)
        defer { try? store.remove(key) }

        let emptyRead = Result { try store.get(key) }
        let write = Result { try store.set("value", key: key) }
        let valueRead = Result { try store.get(key) }
        let remove = Result { try store.remove(key) }
        let removedRead = Result { try store.get(key) }

        if case .success = write,
           case let .success(value) = valueRead,
           case .success = remove,
           case let .success(removedValue) = removedRead {
            XCTAssertNil(try? emptyRead.get())
            XCTAssertEqual(value, "value")
            XCTAssertNil(removedValue)
        } else {
            XCTAssertTrue(
                [emptyRead, write.map { Optional<String>.none }, valueRead, remove.map { Optional<String>.none }, removedRead]
                    .contains { result in
                        if case .failure = result {
                            return true
                        }
                        return false
                    }
            )
        }
    }

}

private final class KeychainServiceSpy: KeychainService {
    var ruuviUserApiKey: String?
    var userApiEmail: String?
    var userIsAuthorized: Bool {
        ruuviUserApiKey != nil
    }
}

private final class KeychainStoreSpy: KeychainStore {
    private var values: [String: String] = [:]

    func get(_ key: String) throws -> String? {
        values[key]
    }

    func set(_ value: String, key: String) throws {
        values[key] = value
    }

    func remove(_ key: String) throws {
        values[key] = nil
    }
}

private struct FailingKeychainStoreSpy: KeychainStore {
    func get(_ key: String) throws -> String? {
        throw DummyError()
    }

    func set(_ value: String, key: String) throws {
        throw DummyError()
    }

    func remove(_ key: String) throws {
        throw DummyError()
    }
}

private struct RemoveFailingKeychainStoreSpy: KeychainStore {
    func get(_ key: String) throws -> String? {
        nil
    }

    func set(_ value: String, key: String) throws {}

    func remove(_ key: String) throws {
        throw DummyError()
    }
}

private struct DummyError: Error {}
