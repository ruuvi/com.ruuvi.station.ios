import Foundation
import XCTest
@testable import station

@MainActor final class AccountLifecycleTests: XCTestCase {
    func testRepeatedDeleteTapsShareOneRequestAndAllowRetryAfterItFinishes() async {
        let fixture = AccountFixture()
        var releases = [CheckedContinuation<Void, Never>]()
        fixture.cloud.onDeleteAccount = { _ in
            await withCheckedContinuation { releases.append($0) }
            return true
        }
        fixture.presenter.viewDidTapDeleteButton()
        await waitForAppState("delete waiting") { !releases.isEmpty }
        fixture.presenter.viewDidTapDeleteButton()
        await flushAppBindings()
        XCTAssertEqual(fixture.cloud.deletedEmails.count, 1)
        let requestCount = releases.count
        releases.forEach { $0.resume() }
        releases.removeAll()
        await waitForAppState("delete done") { fixture.activity.dismissals.count == requestCount }
        XCTAssertEqual(fixture.view.deletions, 1)
        fixture.cloud.onDeleteAccount = { _ in true }
        fixture.presenter.viewDidTapDeleteButton()
        await waitForAppState("second deliberate deletion") { fixture.activity.dismissals.count == requestCount + 1 }
        XCTAssertEqual(fixture.view.deletions, 2)
    }

    func testClosingWhileDeletingReleasesThePresenterAndDismissesTheLoadingIndicator() async {
        let fixture = AccountFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.cloud.onDeleteAccount = { _ in
            await withCheckedContinuation { release = $0 }
            return true
        }
        fixture.presenter.viewDidTapDeleteButton()
        await waitForAppState("pending deletion") { release != nil }
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(presenter)
        release?.resume(); release = nil
        await waitForAppState("deletion indicator dismissed") { fixture.activity.dismissals.count == 1 }
        XCTAssertEqual(fixture.view.deletions, 0)
    }

    func testSignOutClearsCloudModeAndRefreshesBothWidgetKinds() async {
        let fixture = AccountFixture()
        fixture.settings.cloudModeEnabled = true
        fixture.push.fcmToken = "old-token"
        fixture.push.fcmTokenLastRefreshed = Date()
        fixture.presenter.confirmSignOut()
        await waitForAppState("logout complete") { fixture.router.dismissals == 1 }
        await waitForAppState("push token removed") { fixture.push.fcmToken == nil }
        XCTAssertFalse(fixture.settings.cloudModeEnabled)
        XCTAssertNil(fixture.push.fcmTokenLastRefreshed)
        XCTAssertEqual(fixture.notification.unregisters.compactMap { $0 }, ["old-token"])
        XCTAssertEqual(
            Set(fixture.widgets),
            [AppAssemblyConstants.simpleWidgetKindId, AppAssemblyConstants.multiSensorWidgetKindId])
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
    }

    func testSignOutFailureKeepsTheAccountOpenAndExplainsTheFailure() async {
        let fixture = AccountFixture()
        fixture.settings.cloudModeEnabled = true
        fixture.auth.failure = .failedToParseNetworkResponse
        fixture.presenter.confirmSignOut()
        await waitForAppState("logout failed") { fixture.activity.dismissals.count == 1 }
        XCTAssertEqual(fixture.router.dismissals, 0)
        XCTAssertTrue(fixture.settings.cloudModeEnabled)
        XCTAssertTrue(fixture.widgets.isEmpty)
        XCTAssertEqual(fixture.errors.errors.count, 1)
    }

    func testLateTokenRemovalCannotEraseANewerPushRegistration() async {
        let fixture = AccountFixture()
        fixture.push.fcmToken = "old-token"
        var release: CheckedContinuation<Void, Never>?
        fixture.notification.beforeUnregister = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.confirmSignOut()
        await waitForAppState("unregister waiting") { release != nil }
        fixture.push.fcmToken = "new-token"
        let refreshed = Date()
        fixture.push.fcmTokenLastRefreshed = refreshed
        release?.resume(); release = nil
        await waitForAppState("token removal completed") { fixture.activity.updates.contains(.success(message: nil)) }
        XCTAssertEqual(fixture.push.fcmToken, "new-token")
        XCTAssertEqual(fixture.push.fcmTokenLastRefreshed, refreshed)
    }

    func testPushUnregisterFinishesBeforeLogoutRevokesTheCredentials() async {
        let fixture = AccountFixture()
        fixture.push.fcmToken = "registered-token"
        var release: CheckedContinuation<Void, Never>?
        fixture.notification.beforeUnregister = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.confirmSignOut()
        await waitForAppState("unregister pending") { release != nil }
        await flushAppBindings()
        XCTAssertEqual(fixture.auth.calls, 0)
        release?.resume(); release = nil
        await waitForAppState("logout after unregister") { fixture.router.dismissals == 1 }
        XCTAssertEqual(fixture.auth.calls, 1)
    }

    func testFailedOrMissingPushUnregisterStillAllowsLocalSignOut() async {
        for token in [nil, "", "registered-token"] {
            let fixture = AccountFixture()
            fixture.push.fcmToken = token
            fixture.notification.failure = .failedToParseNetworkResponse
            fixture.presenter.confirmSignOut()
            await waitForAppState("local logout") { fixture.router.dismissals == 1 }
            XCTAssertEqual(fixture.notification.unregisters.count, token == "registered-token" ? 1 : 0)
            XCTAssertEqual(fixture.auth.calls, 1)
            XCTAssertEqual(fixture.activity.dismissals.count, 1)
            XCTAssertTrue(fixture.errors.errors.isEmpty)
        }
    }

    func testConfirmedLogoutContinuesWithoutRetainingTheClosedPresenter() async {
        let fixture = AccountFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.auth.beforeLogout = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.confirmSignOut()
        await waitForAppState("logout pending") { release != nil }
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(presenter)
        release?.resume(); release = nil
        await waitForAppState("logout activity dismissed") { fixture.activity.dismissals.count == 1 }
        XCTAssertFalse(fixture.settings.cloudModeEnabled)
        XCTAssertEqual(fixture.widgets.count, 2)
    }

}
