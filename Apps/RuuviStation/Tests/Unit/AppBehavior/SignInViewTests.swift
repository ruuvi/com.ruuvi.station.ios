import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class SignInViewTests: XCTestCase {
    func testEmailAndCodeViewsRenderAndForwardOnlyValidUserActions() async throws {
        let output = SignInViewOutputSpy()
        let controller = SignInViewController()
        controller.output = output
        controller.viewModel = SignInViewModel()
        controller.loadViewIfNeeded()
        controller.viewModel = SignInViewModel()
        controller.view.frame = .init(x: 0, y: 0, width: 402, height: 874)
        controller.view.layoutIfNeeded()
        let emailView = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? SignInView }.first)
        let verifyView = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? SignInVerifyView }.first)
        let codeView = try XCTUnwrap(descendants(verifyView).compactMap { $0 as? RuuviCodeView }.first)
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(emailView.alpha, 1)
        XCTAssertEqual(verifyView.alpha, 0)
        emailView.populateEmail(from: " OWNER@Example.com \n")
        XCTAssertEqual(emailView.enteredEmail(), "owner@example.com")
        let request = try XCTUnwrap(descendants(emailView).compactMap { $0 as? UIButton }.first)
        XCTAssertEqual(request.title(for: .normal), RuuviLocalization.requestCode)
        request.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.emails, ["owner@example.com"])
        XCTAssertTrue(
            descendants(verifyView).compactMap { ($0 as? UILabel)?.text }
                .contains(RuuviLocalization.SignIn.checkMailbox("owner@example.com")))
        controller.viewModel.showVerficationScreen.value = true
        await flushAppBindings()
        XCTAssertEqual(emailView.alpha, 0)
        XCTAssertEqual(verifyView.alpha, 1)
        codeView.autofill(with: "BCD")
        XCTAssertTrue(output.codes.isEmpty)
        codeView.autofill(with: "BCD2")
        XCTAssertEqual(output.codes, ["BCD2"])
        controller.fromDeepLink = true
        controller.viewModel.inputText.value = "GH45"
        await flushAppBindings()
        XCTAssertEqual(codeView.ruuviCode(), "GH45")
        XCTAssertEqual(output.codes, ["BCD2"])
        controller.showInvalidTokenEntered()
        XCTAssertEqual(codeView.ruuviCode(), "")
        controller.fromDeepLink = false
        codeView.autofill(with: "JK67")
        XCTAssertEqual(output.codes, ["BCD2", "JK67"])
        controller.viewModel.showVerficationScreen.value = false
        await flushAppBindings()
        let skip = try XCTUnwrap(
            descendants(controller.view).compactMap { $0 as? UIButton }
                .first { $0.title(for: .normal) == RuuviLocalization.useWithoutAccount })
        skip.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.skips, 1)
        let back = try XCTUnwrap(controller.navigationItem.leftBarButtonItem)
        _ = (back.target as? NSObject)?.perform(try XCTUnwrap(back.action))
        XCTAssertEqual(output.backs, 1)
        controller.viewWillAppear(false)
        controller.viewWillDisappear(false)
        emailView.touchesBegan([], with: nil)
        verifyView.touchesBegan([], with: nil)
        verifyView.updateMessage(with: nil)
    }

    func testSignInErrorsPresentSpecificMessagesAndDismissCleanly() async throws {
        let controller = SignInViewController()
        let output = SignInViewOutputSpy()
        controller.output = output
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKeyAndVisible() }
        controller.viewModel = SignInViewModel()
        let checks: [(String, () -> Void)] = [
            (
                RuuviLocalization.SignIn.EmailMismatch.Alert.message("a@example.com", "b@example.com", "a@example.com"),
                { controller.showEmailsAreDifferent(requestedEmail: "a@example.com", validatedEmail: "b@example.com") }
            ),
            (RuuviLocalization.SignIn.EmailMissing.Alert.message, { controller.showFailedToGetRequestedEmail() }),
            (RuuviLocalization.UserApiError.erInvalidEmailAddress, { controller.showInvalidEmailEntered() }),
            (
                RuuviLocalization.RuuviCloudApiError.unexpectedHTTPStatusCodeShouldRetry,
                { controller.showUnexpectedHTTPStatusCodeError() }
            ),
        ]
        for (message, show) in checks {
            show()
            let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.message, message)
            XCTAssertEqual(alert.actions.map(\.title), [RuuviLocalization.ok])
            XCTAssertEqual(alert.actions.first?.style, .cancel)
            await waitForAppState("alert presentation complete") { !alert.isBeingPresented }
            await withCheckedContinuation { continuation in
                controller.dismiss(animated: false) { continuation.resume() }
            }
        }
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}

private final class SignInViewOutputSpy: SignInViewOutput {
    var loads = 0
    var backs = 0
    var skips = 0
    var recovery = 0
    var emails = [String?]()
    var codes = [String]()
    func viewDidLoad() { loads += 1 }
    func viewDidTapBack() { backs += 1 }
    func viewDidTapUseWithoutAccount() { skips += 1 }
    func viewDidTapRequestCodeButton(for email: String?) { emails.append(email) }
    func viewDidTapEnterCodeManually(code: String) { codes.append(code) }
    func viewDidTapOkFromUnexpectedHTTPStatusCodeError() { recovery += 1 }
}
