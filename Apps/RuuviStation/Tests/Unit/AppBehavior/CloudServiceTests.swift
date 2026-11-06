import Foundation
import RuuviDaemon
import RuuviLocal
import RuuviService
import RuuviOntology
import XCTest
@testable import station

@MainActor final class CloudServiceTests: XCTestCase {
    func testCloudStatusAndHistoryNotificationsPreserveTheirPayloadAndCanBeStopped() {
        let fixture = CloudServiceFixture()
        defer { fixture.service.stopObserving() }
        fixture.service.startObserving()
        fixture.service.startObserving()
        let center = NotificationCenter.default
        center.post(name: .NetworkSyncDidChangeCommonStatus, object: nil)
        for status in [NetworkSyncStatus.syncing, .complete, .none] {
            center.post(
                name: .NetworkSyncDidChangeCommonStatus, object: nil,
                userInfo: [NetworkSyncStatusKey.status: status])
        }
        let mac = "AA:BB:CC:DD:EE:FF".mac
        center.post(
            name: .NetworkSyncHistoryDidChangeStatus, object: nil,
            userInfo: [NetworkSyncStatusKey.mac: mac])
        for status in [NetworkSyncStatus.syncing, .complete, .none] {
            center.post(
                name: .NetworkSyncHistoryDidChangeStatus, object: nil,
                userInfo: [NetworkSyncStatusKey.mac: mac, NetworkSyncStatusKey.status: status])
        }
        XCTAssertEqual(fixture.delegate.activity, [true, false, false])
        XCTAssertEqual(fixture.delegate.completions, [true])
        XCTAssertEqual(fixture.delegate.history.map(\.0), [true, false, false])
        XCTAssertEqual(fixture.delegate.history.map(\.1), Array(repeating: mac.value, count: 3))
        fixture.service.stopObserving()
        center.post(
            name: .NetworkSyncDidChangeCommonStatus, object: nil,
            userInfo: [NetworkSyncStatusKey.status: NetworkSyncStatus.syncing])
        center.post(
            name: .NetworkSyncHistoryDidChangeStatus, object: nil,
            userInfo: [NetworkSyncStatusKey.mac: mac, NetworkSyncStatusKey.status: NetworkSyncStatus.syncing])
        XCTAssertEqual(fixture.delegate.activity.count, 3)
        XCTAssertEqual(fixture.delegate.history.count, 3)
    }

    func testIdentityLogoutAndCloudModeFollowTheCurrentUserAndObserverLifetime() {
        let fixture = CloudServiceFixture()
        defer { fixture.service.stopObserving() }
        XCTAssertFalse(fixture.service.isAuthorized())
        XCTAssertNil(fixture.service.getUserEmail())
        fixture.user.isAuthorized = true
        fixture.user.email = "owner@example.com"
        XCTAssertTrue(fixture.service.isAuthorized())
        XCTAssertEqual(fixture.service.getUserEmail(), "owner@example.com")
        fixture.service.startObserving()
        fixture.settings.cloudModeEnabled = true
        NotificationCenter.default.post(name: .CloudModeDidChange, object: nil)
        XCTAssertTrue(fixture.service.isCloudModeEnabled())
        NotificationCenter.default.post(name: .RuuviAuthServiceDidLogout, object: nil)
        XCTAssertEqual(fixture.delegate.modes, [true])
        XCTAssertEqual(fixture.delegate.logouts, [true])
        fixture.service.stopObserving()
        fixture.settings.cloudModeEnabled = false
        NotificationCenter.default.post(name: .CloudModeDidChange, object: nil)
        NotificationCenter.default.post(name: .RuuviAuthServiceDidLogout, object: nil)
        XCTAssertEqual(fixture.delegate.modes, [true])
        XCTAssertEqual(fixture.delegate.logouts, [true])
    }

    func testAuthorizationFailureUnregistersBeforeRevokingCredentialsAndClearsTokenIdentity() async {
        let fixture = CloudServiceFixture()
        defer { fixture.service.stopObserving() }
        fixture.authorize(token: "old")
        fixture.service.startObserving()
        var release: CheckedContinuation<Void, Never>?
        fixture.notification.beforeUnregister = { await withCheckedContinuation { release = $0 } }
        NotificationCenter.default.post(name: .NetworkSyncDidFailForAuthorization, object: nil)
        await waitForAppState("unregister suspended") { release != nil }
        XCTAssertEqual(fixture.auth.calls, 0, "Push removal needs credentials until its request finishes")
        release?.resume(); release = nil
        await waitForAppState("forced logout") { !fixture.delegate.failures.isEmpty }
        XCTAssertEqual(fixture.auth.calls, 1)
        XCTAssertEqual(fixture.notification.unregisters.compactMap { $0 }, ["old"])
        XCTAssertNil(fixture.push.fcmToken)
        XCTAssertNil(fixture.push.fcmTokenId)
        XCTAssertNil(fixture.push.fcmTokenLastRefreshed)
        XCTAssertFalse(fixture.settings.cloudModeEnabled)
        XCTAssertEqual(fixture.delegate.modes, [false])
        XCTAssertEqual(fixture.delegate.failures, [true])
    }

    func testRepeatedAuthorizationFailuresShareOneLogoutAndAllowRetryAfterFailure() async {
        let fixture = CloudServiceFixture()
        fixture.authorize(token: nil)
        fixture.auth.failure = .failedToParseNetworkResponse
        var releases = [CheckedContinuation<Void, Never>]()
        fixture.auth.beforeLogout = { await withCheckedContinuation { releases.append($0) } }
        fixture.service.forceLogout()
        await waitForAppState("logout suspended") { !releases.isEmpty }
        fixture.service.forceLogout()
        await flushAppBindings()
        XCTAssertEqual(fixture.auth.calls, 1)
        let count = releases.count
        releases.forEach { $0.resume() }; releases.removeAll()
        await waitForAppState("failed logout completes") { fixture.delegate.failures.count == count }
        XCTAssertTrue(fixture.settings.cloudModeEnabled)
        XCTAssertTrue(fixture.delegate.modes.isEmpty)
        fixture.auth.beforeLogout = nil
        fixture.auth.failure = nil
        fixture.service.forceLogout()
        await waitForAppState("retry completes") { fixture.delegate.failures.count == count + 1 }
        XCTAssertEqual(fixture.auth.calls, 2)
        XCTAssertFalse(fixture.settings.cloudModeEnabled)
        fixture.service.stopObserving()
    }

    func testOldUnregisterResponseCannotEraseANewerRegistration() async {
        let fixture = CloudServiceFixture()
        defer { fixture.service.stopObserving() }
        fixture.authorize(token: "old")
        var release: CheckedContinuation<Void, Never>?
        var requestFinished = false
        fixture.notification.beforeUnregister = {
            await withCheckedContinuation { release = $0 }
            requestFinished = true
        }
        fixture.service.forceLogout()
        await waitForAppState("old registration removal") { release != nil }
        let refreshed = Date()
        fixture.push.fcmToken = "new"
        fixture.push.fcmTokenId = 99
        fixture.push.fcmTokenLastRefreshed = refreshed
        release?.resume(); release = nil
        await waitForAppState("old removal finishes") { requestFinished }
        await flushAppBindings()
        XCTAssertEqual(fixture.push.fcmToken, "new")
        XCTAssertEqual(fixture.push.fcmTokenId, 99)
        XCTAssertEqual(fixture.push.fcmTokenLastRefreshed, refreshed)
    }

    func testMissingEmptyAndFailedPushRemovalStillFinishLocalLogout() async {
        for token in [nil, "", "old"] {
            let fixture = CloudServiceFixture()
            defer { fixture.service.stopObserving() }
            fixture.authorize(token: token)
            fixture.notification.failure = .failedToParseNetworkResponse
            fixture.service.forceLogout()
            await waitForAppState("local logout") { fixture.delegate.failures.count == 1 }
            XCTAssertEqual(fixture.auth.calls, 1)
            XCTAssertEqual(fixture.notification.unregisters.count, token == "old" ? 1 : 0)
            XCTAssertEqual(fixture.push.fcmToken, token)
            XCTAssertFalse(fixture.settings.cloudModeEnabled)
        }
    }

    func testUnauthorizedUserDoesNotStartLogoutOrNotifyFailure() async {
        let fixture = CloudServiceFixture()
        fixture.service.forceLogout()
        await flushAppBindings()
        XCTAssertEqual(fixture.auth.calls, 0)
        XCTAssertTrue(fixture.notification.unregisters.isEmpty)
        XCTAssertTrue(fixture.delegate.failures.isEmpty)
    }
}

@MainActor private final class CloudServiceFixture {
    let settings = AppTestSettings()
    let user = DefaultsUserSpy()
    let auth = AccountAuthSpy()
    let push = AccountPushSpy()
    let notification = AccountNotificationSpy()
    let daemon = SignInDaemonSpy()
    let delegate = CloudServiceDelegateSpy()
    lazy var service: RuuviCloudService = {
        let service = RuuviCloudService(
            cloudSyncDaemon: daemon, cloudNotificationService: notification,
            authService: auth, ruuviUser: user, settings: settings, pnManager: push)
        service.delegate = delegate
        return service
    }()
    func authorize(token: String?) {
        user.isAuthorized = true
        settings.cloudModeEnabled = true
        push.fcmToken = token
        push.fcmTokenId = 42
        push.fcmTokenLastRefreshed = Date()
    }
}

private final class CloudServiceDelegateSpy: RuuviCloudServiceDelegate {
    var logins = [Bool]()
    var logouts = [Bool]()
    var activity = [Bool]()
    var completions = [Bool]()
    var history = [(Bool, String)]()
    var failures = [Bool]()
    var modes = [Bool]()
    func ruuviCloudService(_ service: RuuviCloudService, userDidLogin loggedIn: Bool) { logins.append(loggedIn) }
    func ruuviCloudService(_ service: RuuviCloudService, userDidLogOut loggedOut: Bool) { logouts.append(loggedOut) }
    func ruuviCloudService(_ service: RuuviCloudService, syncStatusDidChange isRefreshing: Bool) {
        activity.append(isRefreshing)
    }
    func ruuviCloudService(_ service: RuuviCloudService, syncDidComplete: Bool) { completions.append(syncDidComplete) }
    func ruuviCloudService(_ service: RuuviCloudService, historySyncInProgress inProgress: Bool, for macId: String) {
        history.append((inProgress, macId))
    }
    func ruuviCloudService(_ service: RuuviCloudService, authorizationFailed: Bool) {
        failures.append(authorizationFailed)
    }
    func ruuviCloudService(_ service: RuuviCloudService, cloudModeDidChange isEnabled: Bool) {
        modes.append(isEnabled)
    }
}
