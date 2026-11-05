import Foundation
import RuuviCloud
import UIKit
import XCTest
@testable import station

@MainActor final class SignInLifecycleTests: XCTestCase {
    func testRepeatedLoadsObserveLinksOnceAndRejectMalformedOrIrrelevantLinks() async {
        let fixture = SignInFixture()
        fixture.readyToVerify()
        fixture.presenter.viewDidLoad()
        fixture.notifications.post(name: .DidOpenWithUniversalLink, object: nil)
        for info: [AnyHashable: Any] in [
            [:], ["token": "123"], ["path": "verify", "token": "123"],
            ["path": UniversalLinkType.verify], ["path": UniversalLinkType.verify, "token": ""],
        ] {
            fixture.notifications.post(name: .DidOpenWithUniversalLink, object: nil, userInfo: info)
        }
        XCTAssertFalse(fixture.view.fromDeepLink)
        XCTAssertTrue(fixture.cloud.requestedCodes.isEmpty)
        fixture.notifications.post(
            name: .DidOpenWithUniversalLink, object: nil,
            userInfo: ["path": UniversalLinkType.verify, "token": "123456"])
        XCTAssertTrue(fixture.view.fromDeepLink)
        XCTAssertEqual(fixture.view.viewModel.inputText.value, "123456")
        await waitForAppState("deep link login") { fixture.output.logins > 0 }
        XCTAssertEqual(fixture.cloud.requestedCodes, ["123456"])
        XCTAssertEqual(fixture.output.logins, 1)
        fixture.notifications.post(
            name: .DidOpenWithUniversalLink, object: nil,
            userInfo: ["path": UniversalLinkType.verify, "token": "another"])
        XCTAssertEqual(fixture.view.viewModel.inputText.value, "123456")
    }

    func testBackingOutCancelsDelayedDeepLinkVerification() async {
        let fixture = SignInFixture(state: .enterVerificationCode("123456"))
        fixture.presenter.viewDidLoad()
        XCTAssertEqual(fixture.view.viewModel.inputText.value, "123456")
        fixture.presenter.viewDidTapBack()
        try? await Task.sleep(nanoseconds: 850_000_000)
        XCTAssertTrue(fixture.cloud.requestedCodes.isEmpty)
        XCTAssertEqual(fixture.view.viewModel.showVerficationScreen.value, false)
    }

    func testRepeatedRequestAndVerificationTapsDoNotDuplicateNetworkOperations() async {
        let fixture = SignInFixture()
        var requestRelease: CheckedContinuation<Void, Never>?
        fixture.cloud.onRequestCode = { email in
            if requestRelease == nil { await withCheckedContinuation { requestRelease = $0 } }
            return email
        }
        fixture.presenter.viewDidLoad()
        fixture.presenter.viewDidTapRequestCodeButton(for: "owner@example.com")
        await waitForAppState("request pending") { requestRelease != nil }
        fixture.presenter.viewDidTapRequestCodeButton(for: "other@example.com")
        await Task.yield()
        XCTAssertEqual(fixture.cloud.requestedEmails, ["owner@example.com"])
        fixture.cloud.onRequestCode = nil
        requestRelease?.resume()
        await waitForAppState("verification screen") { fixture.view.viewModel.showVerficationScreen.value == true }
        var verifyRelease: CheckedContinuation<Void, Never>?
        fixture.cloud.onValidateCode = { _ in
            if verifyRelease == nil { await withCheckedContinuation { verifyRelease = $0 } }
            return .init(email: "owner@example.com", apiKey: "token")
        }
        fixture.presenter.viewDidTapEnterCodeManually(code: "123456")
        await waitForAppState("verification pending") { verifyRelease != nil }
        fixture.presenter.viewDidTapEnterCodeManually(code: "123456")
        await Task.yield()
        XCTAssertEqual(fixture.cloud.requestedCodes, ["123456"])
        fixture.cloud.onValidateCode = nil
        verifyRelease?.resume()
        await waitForAppState("login finished") { fixture.output.logins == 1 }
    }

    func testClosingRequestingScreenReleasesPresenterAndIgnoresLateResponse() async {
        let fixture = SignInFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.cloud.onRequestCode = { email in
            await withCheckedContinuation { release = $0 }
            return email
        }
        fixture.presenter.viewDidLoad()
        fixture.presenter.viewDidTapRequestCodeButton(for: "owner@example.com")
        await waitForAppState("request pending") { release != nil }
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(presenter)
        release?.resume()
        await Task.yield()
        XCTAssertNil(fixture.user.email)
        XCTAssertEqual(fixture.view.viewModel.showVerficationScreen.value, false)
    }

    func testIdleLifecycleDoesNotShowProgressAndFailedLogoutDoesNotDismissScreen() async {
        let fixture = SignInFixture()
        fixture.presenter.viewDidLoad()
        fixture.notifications.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        fixture.notifications.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertEqual(fixture.activity.shown, 0)
        XCTAssertEqual(fixture.activity.dismissed, 0)
        fixture.auth.failure = .failedToParseNetworkResponse
        fixture.presenter.viewDidTapOkFromUnexpectedHTTPStatusCodeError()
        await waitForAppState("logout attempted") { fixture.auth.logouts == 1 }
        await Task.yield()
        XCTAssertEqual(fixture.router.dismissals, 0)
    }
}
