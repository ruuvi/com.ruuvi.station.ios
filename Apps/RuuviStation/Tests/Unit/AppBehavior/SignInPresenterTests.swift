import Foundation
import RuuviCloud
import RuuviService
import UIKit
import XCTest
@testable import station

@MainActor final class SignInPresenterTests: XCTestCase {
    func testRequestCodeValidatesAndNormalizesEmailAndBackReturnsToEmailEntry() async {
        let fixture = SignInFixture()
        fixture.presenter.viewDidLoad()
        XCTAssertEqual(fixture.view.viewModel.showVerficationScreen.value, false)
        for email in [nil, "", "owner", "a@b", "a b@example.com", "a@example.c"] as [String?] {
            fixture.presenter.viewDidTapRequestCodeButton(for: email)
        }
        XCTAssertEqual(fixture.view.invalidEmails, 6)
        XCTAssertTrue(fixture.cloud.requestedEmails.isEmpty)
        fixture.cloud.onRequestCode = { email in email }
        fixture.presenter.viewDidTapRequestCodeButton(for: "OWNER@Example.com")
        await waitForAppState("verification screen") { fixture.view.viewModel.showVerficationScreen.value == true }
        XCTAssertEqual(fixture.cloud.requestedEmails, ["owner@example.com"])
        XCTAssertEqual(fixture.user.email, "owner@example.com")
        XCTAssertEqual(fixture.activity.shown, 1)
        XCTAssertEqual(fixture.activity.dismissed, 1)
        fixture.presenter.viewDidTapRequestCodeButton(for: "another@example.com")
        XCTAssertEqual(fixture.cloud.requestedEmails.count, 1)
        fixture.presenter.viewDidTapBack()
        XCTAssertEqual(fixture.view.viewModel.showVerficationScreen.value, false)
        XCTAssertTrue(fixture.router.pops.isEmpty)
        fixture.presenter.viewDidTapBack()
        XCTAssertEqual(fixture.router.pops, [true])
        fixture.presenter.viewDidTapUseWithoutAccount()
        XCTAssertEqual(fixture.output.skips, 1)
        var completed = false
        fixture.presenter.dismiss { completed = true }
        XCTAssertTrue(completed)
        XCTAssertEqual(fixture.router.dismissals, 1)
    }

    func testFailedRequestAndInvalidVerificationLeaveTheUserSignedOutAndDismissProgress() async {
        let fixture = SignInFixture()
        fixture.presenter.viewDidLoad()
        fixture.presenter.viewDidTapRequestCodeButton(for: "owner@example.com")
        await waitForAppState("request failure") { fixture.errors.errors.count == 1 }
        XCTAssertEqual(fixture.activity.dismissed, 1)
        XCTAssertEqual(fixture.view.viewModel.showVerficationScreen.value, false)
        fixture.presenter.viewDidTapEnterCodeManually(code: "incorrect")
        await waitForAppState("verification failure") { fixture.view.invalidTokens == 1 }
        XCTAssertEqual(fixture.cloud.requestedCodes, ["incorrect"])
        XCTAssertEqual(fixture.errors.errors.count, 2)
        XCTAssertEqual(fixture.activity.dismissed, 2)
        XCTAssertFalse(fixture.user.isAuthorized)
        XCTAssertEqual(fixture.sync.historyCalls, 0)
    }

    func testVerificationRejectsMismatchedOrMissingRequestedEmail() async {
        for requestedEmail in ["other@example.com", nil] {
            let fixture = SignInFixture()
            fixture.readyToVerify()
            fixture.user.email = requestedEmail
            fixture.presenter.viewDidTapEnterCodeManually(code: "123456")
            await waitForAppState("email mismatch shown") { fixture.activity.dismissed == 1 }
            XCTAssertFalse(fixture.user.isAuthorized)
            XCTAssertEqual(fixture.sync.historyCalls, 0)
            if let requestedEmail {
                XCTAssertEqual(fixture.view.mismatches.first?.0, requestedEmail)
                XCTAssertEqual(fixture.view.mismatches.first?.1, "owner@example.com")
                XCTAssertEqual(fixture.view.missingEmail, 0)
            } else {
                XCTAssertEqual(fixture.view.missingEmail, 1)
                XCTAssertTrue(fixture.view.mismatches.isEmpty)
            }
        }
    }

    func testSuccessfulLoginAuthenticatesSyncsRegistersPushAndRefreshesBothWidgets() async {
        for previouslySignedIn in [false, true] {
            let fixture = SignInFixture()
            fixture.readyToVerify()
            fixture.settings.signedInAtleastOnce = previouslySignedIn
            fixture.presenter.viewDidTapEnterCodeManually(code: "123456")
            await waitForAppState("login completed") {
                fixture.output.logins == 1 && fixture.notification.tokens.count == 1
            }
            XCTAssertEqual(fixture.user.apiKey, "validated-key")
            XCTAssertTrue(fixture.user.isAuthorized)
            XCTAssertTrue(fixture.settings.signedInAtleastOnce)
            XCTAssertFalse(fixture.settings.isSyncing)
            XCTAssertFalse(fixture.settings.syncExtensiveChangesInProgress)
            XCTAssertEqual(fixture.sync.historyCalls, 1)
            XCTAssertEqual(fixture.sync.latestCalls, 0)
            XCTAssertEqual(fixture.daemon.starts, 1)
            XCTAssertEqual(fixture.activity.dismissed, 1)
            XCTAssertEqual(fixture.tokenRequests, 1)
            XCTAssertEqual(fixture.notification.tokens, ["fixture-token"])
            XCTAssertEqual(fixture.notification.languages, [fixture.settings.language])
            XCTAssertEqual(fixture.notification.sounds, [fixture.settings.alertSound])
            XCTAssertEqual(
                Set(fixture.widgetKinds),
                [AppAssemblyConstants.simpleWidgetKindId, AppAssemblyConstants.multiSensorWidgetKindId])
        }
    }

    func testSyncRetryIsBoundedAndNonRetryableFailuresAreReported() async {
        let retryError = RuuviServiceError.ruuviCloud(.api(.unexpectedHTTPStatusCodeShouldRetry(503)))
        for failRetry in [false, true] {
            let fixture = SignInFixture()
            fixture.readyToVerify()
            fixture.sync.historyError = retryError
            fixture.sync.latestError = failRetry ? retryError : nil
            fixture.presenter.viewDidTapEnterCodeManually(code: "123456")
            await waitForAppState("retry completed") { fixture.output.logins + fixture.view.unexpectedStatuses == 1 }
            XCTAssertEqual(fixture.sync.historyCalls, 1)
            XCTAssertEqual(fixture.sync.latestCalls, 1)
            XCTAssertEqual(fixture.output.logins, failRetry ? 0 : 1)
            XCTAssertEqual(fixture.view.unexpectedStatuses, failRetry ? 1 : 0)
            XCTAssertEqual(fixture.activity.dismissed, 1)
        }
        for error in [RuuviServiceError.failedToParseNetworkResponse, .ruuviCloud(.notAuthorized)] {
            let fixture = SignInFixture()
            fixture.readyToVerify()
            fixture.sync.historyError = error
            fixture.presenter.viewDidTapEnterCodeManually(code: "123456")
            await waitForAppState("sync failure") { fixture.errors.errors.count == 1 }
            XCTAssertEqual(fixture.sync.latestCalls, 0)
            XCTAssertEqual(fixture.output.logins, 0)
            XCTAssertFalse(fixture.settings.isSyncing)
            XCTAssertFalse(fixture.settings.syncExtensiveChangesInProgress)
            fixture.presenter.viewDidTapBack()
            XCTAssertEqual(fixture.view.viewModel.showVerficationScreen.value, false)
            XCTAssertEqual(fixture.activity.dismissed, 1)
        }
    }

    func testAppLifecycleDuringSyncAndLogoutRecovery() async {
        let fixture = SignInFixture()
        fixture.readyToVerify()
        var release: CheckedContinuation<Void, Never>?
        fixture.sync.beforeHistory = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.viewDidTapEnterCodeManually(code: "123456")
        await waitForAppState("sync suspended") { release != nil }
        XCTAssertTrue(fixture.settings.isSyncing)
        XCTAssertTrue(fixture.settings.syncExtensiveChangesInProgress)
        fixture.presenter.viewDidTapBack()
        XCTAssertTrue(fixture.router.pops.isEmpty)
        fixture.notifications.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertEqual(fixture.activity.dismissed, 1)
        fixture.notifications.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertEqual(fixture.activity.shown, 2)
        release?.resume()
        await waitForAppState("sync finished") { fixture.output.logins == 1 }
        fixture.presenter.viewDidTapOkFromUnexpectedHTTPStatusCodeError()
        await waitForAppState("logout recovery") { fixture.router.dismissals == 1 }
        XCTAssertEqual(fixture.auth.logouts, 1)
        XCTAssertFalse(fixture.settings.isSyncing)
    }
}
