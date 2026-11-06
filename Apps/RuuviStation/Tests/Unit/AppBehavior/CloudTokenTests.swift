import Foundation
import RuuviCloud
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class CloudTokenTests: XCTestCase {
    func testTokenRegistrationSendsDevicePreferencesAndPersistsOnlyTheSuccessfulResponse() async throws {
        let fixture = CloudTokenFixture()
        defer { fixture.cleanup() }
        let before = Date()
        let id = try await fixture.service.set(
            token: "new-token", name: "My iPhone", data: "metadata",
            language: .finnish, sound: .ruuviSpeak)
        XCTAssertEqual(id, 42)
        let request = try XCTUnwrap(fixture.cloud.pushRegistrations.first)
        XCTAssertEqual(request.token, "new-token")
        XCTAssertEqual(request.type, "ios")
        XCTAssertEqual(request.name, "My iPhone")
        XCTAssertEqual(request.data, "metadata")
        XCTAssertEqual(request.params?["language"], "fi")
        XCTAssertEqual(request.params?["soundFile"], "ruuvi_speak.caf")
        XCTAssertEqual(fixture.push.fcmToken, "new-token")
        XCTAssertEqual(fixture.push.fcmTokenId, 42)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(fixture.push.fcmTokenLastRefreshed), before)
    }

    func testRecentIdenticalTokenUsesCacheButExpiredChangedAndUnidentifiedTokensRefresh() async throws {
        let fixture = CloudTokenFixture()
        defer { fixture.cleanup() }
        fixture.push.fcmToken = "same"
        fixture.push.fcmTokenId = 7
        fixture.push.fcmTokenLastRefreshed = Date()
        let cached = try await fixture.service.set(
            token: "same", name: nil, data: nil, language: .english, sound: .systemDefault)
        XCTAssertEqual(cached, 7)
        XCTAssertTrue(fixture.cloud.pushRegistrations.isEmpty)
        fixture.push.fcmTokenLastRefreshed = Date().addingTimeInterval(-9 * 86400)
        let refreshed = try await fixture.service.set(
            token: "same", name: nil, data: nil, language: .english, sound: .systemDefault)
        XCTAssertEqual(refreshed, 42)
        _ = try await fixture.service.set(
            token: "changed", name: nil, data: nil, language: .english, sound: .systemDefault)
        fixture.push.fcmTokenId = nil
        _ = try await fixture.service.set(
            token: "changed", name: nil, data: nil, language: .english, sound: .systemDefault)
        XCTAssertEqual(fixture.cloud.pushRegistrations.map(\.token), ["same", "changed", "changed"])
    }

    func testSoundOrLanguageChangesReregisterEvenWhenTheTokenWasRecentlyRefreshed() async throws {
        let fixture = CloudTokenFixture()
        defer { fixture.cleanup() }
        fixture.push.fcmToken = "token"
        fixture.push.fcmTokenId = 7
        fixture.push.fcmTokenLastRefreshed = Date()
        let id = try await fixture.service.set(sound: .ruuviSpeak, language: .german, deviceName: "Renamed phone")
        XCTAssertEqual(id, 42)
        XCTAssertEqual(fixture.cloud.pushRegistrations.first?.params?["language"], "de")
        XCTAssertEqual(fixture.cloud.pushRegistrations.first?.params?["soundFile"], "ruuvi_speak.caf")
        XCTAssertEqual(fixture.cloud.pushRegistrations.first?.name, "Renamed phone")
        XCTAssertNil(fixture.cloud.pushRegistrations.first?.data)
    }

    func testUnauthenticatedOrMissingTokensFailBeforeMakingRequests() async {
        let fixture = CloudTokenFixture()
        defer { fixture.cleanup() }
        for authorized in [false, true] {
            fixture.user.isAuthorized = authorized
            do {
                _ = try await fixture.service.set(
                    token: nil, name: nil, data: nil, language: .english, sound: .systemDefault)
                XCTFail("Invalid registration succeeded")
            } catch {
                guard case .ruuviCloud = error else { return XCTFail("Unexpected \(error)") }
            }
            do {
                _ = try await fixture.service.set(sound: .systemDefault, language: .english, deviceName: nil)
                XCTFail("Missing cached token succeeded")
            } catch {
                guard case .ruuviCloud = error else { return XCTFail("Unexpected \(error)") }
            }
        }
        XCTAssertTrue(fixture.cloud.pushRegistrations.isEmpty)
    }

    func testRegistrationFailuresPreserveThePreviousTokenAndRefreshDate() async {
        let fixture = CloudTokenFixture()
        defer { fixture.cleanup() }
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        fixture.push.fcmToken = "old"
        fixture.push.fcmTokenId = 7
        fixture.push.fcmTokenLastRefreshed = date
        fixture.cloud.pushFailure = .notAuthorized
        do {
            _ = try await fixture.service.set(
                token: "new", name: nil, data: nil, language: .english, sound: .systemDefault)
            XCTFail("Offline registration succeeded")
        } catch { guard case .ruuviCloud(.notAuthorized) = error else { return XCTFail("Unexpected \(error)") } }
        do {
            _ = try await fixture.service.set(sound: .ruuviSpeak, language: .finnish, deviceName: nil)
            XCTFail("Offline preference update succeeded")
        } catch { guard case .ruuviCloud(.notAuthorized) = error else { return XCTFail("Unexpected \(error)") } }
        XCTAssertEqual(fixture.push.fcmToken, "old")
        XCTAssertEqual(fixture.push.fcmTokenId, 7)
        XCTAssertEqual(fixture.push.fcmTokenLastRefreshed, date)
    }

    func testDeviceListingAndUnregistrationPreserveCloudResultsAndErrors() async throws {
        let fixture = CloudTokenFixture()
        defer { fixture.cleanup() }
        fixture.cloud.pushTokens = [RuuviCloudPNTokenStruct(id: 42, lastAccessed: 123, name: "Phone")]
        let tokens = try await fixture.service.listTokens()
        XCTAssertEqual(tokens.map(\.id), [42])
        XCTAssertEqual(tokens.first?.name, "Phone")
        let deleted = try await fixture.service.unregister(token: "token", tokenId: 42)
        XCTAssertTrue(deleted)
        XCTAssertEqual(fixture.cloud.pushUnregisters.first?.0, "token")
        XCTAssertEqual(fixture.cloud.pushUnregisters.first?.1, 42)
        fixture.cloud.pushFailure = .notAuthorized
        do { _ = try await fixture.service.listTokens(); XCTFail("Offline list succeeded") } catch {
            guard case .ruuviCloud(.notAuthorized) = error else { return XCTFail("Unexpected \(error)") }
        }
        do {
            _ = try await fixture.service.unregister(token: nil, tokenId: 42); XCTFail("Offline removal succeeded")
        } catch { guard case .ruuviCloud(.notAuthorized) = error else { return XCTFail("Unexpected \(error)") } }
    }
}

@MainActor private final class CloudTokenFixture {
    let measurements = MeasurementFixture()
    let cloud = AppCloudSpy()
    let pool = AppPoolSpy()
    let user = DefaultsUserSpy()
    let push = AccountPushSpy()
    lazy var service = RuuviServiceCloudNotificationImpl(
        cloud: cloud, pool: pool,
        storage: measurements.storage, ruuviUser: user, pnManager: push)
    init() { user.isAuthorized = true; cloud.pushTokenID = 42 }
    func cleanup() { measurements.cleanup() }
}
