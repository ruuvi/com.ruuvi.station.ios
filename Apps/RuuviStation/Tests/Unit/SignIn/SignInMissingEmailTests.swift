@testable import station
import RuuviUser
import UIKit
import XCTest

@MainActor
final class SignInMissingEmailTests: XCTestCase {
    private var window: UIWindow!
    private var animationsWereEnabled = true

    override func setUpWithError() throws {
        try super.setUpWithError()
        animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.windowLevel = .alert + 1
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        UIView.setAnimationsEnabled(animationsWereEnabled)
        super.tearDown()
    }

    func testTypedCodeWithoutStoredEmailLeavesNoFocusInHiddenCodeFields() throws {
        let module = try makeModule(state: .enterVerificationCode(nil))
        module.emailView.populateEmail(from: "user@example.com")
        XCTAssertNotNil(module.focusedCodeField, "The visible code view takes focus")

        module.presenter.viewDidTapEnterCodeManually(code: "AB12")
        spinRunLoop()

        XCTAssertTrue(module.viewController.presentedViewController is UIAlertController)
        XCTAssertEqual(module.codeView.alpha, 0)
        XCTAssertNil(module.focusedCodeField)
        XCTAssertEqual(module.emailView.enteredEmail(), "user@example.com")

        module.viewController.dismiss(animated: false)
        spinRunLoop()
        XCTAssertNil(module.focusedCodeField, "Closing the alert must not give focus back")
    }

    func testLinkCodeWithoutStoredEmailIsNotLeftInEmailField() throws {
        let module = try makeModule(state: .enterVerificationCode("ab12"))
        XCTAssertEqual(module.emailView.enteredEmail(), "ab12", "A link code is shared with the e-mail field")

        let deadline = Date().addingTimeInterval(5)
        while module.viewController.presentedViewController == nil, Date() < deadline {
            spinRunLoop()
        }
        spinRunLoop()

        XCTAssertTrue(module.viewController.presentedViewController is UIAlertController)
        XCTAssertEqual(module.codeView.alpha, 0)
        XCTAssertNil(module.focusedCodeField)
        XCTAssertEqual(module.emailView.enteredEmail(), "")

        module.viewController.dismiss(animated: false)
        spinRunLoop()
        XCTAssertNil(module.focusedCodeField, "Closing the alert must not give focus back")
    }

    private func makeModule(state: SignInPresenter.State) throws -> Module {
        let viewController = SignInViewController()
        let presenter = SignInPresenter()
        presenter.view = viewController
        presenter.ruuviUser = UserWithoutEmail()
        presenter.configure(with: state, output: nil)
        viewController.output = presenter
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        spinRunLoop()
        return Module(
            presenter: presenter,
            viewController: viewController,
            emailView: try XCTUnwrap(viewController.view.descendants(ofType: SignInView.self).first),
            codeView: try XCTUnwrap(viewController.view.descendants(ofType: SignInVerifyView.self).first)
        )
    }

    private func spinRunLoop() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
}

@MainActor
private struct Module {
    let presenter: SignInPresenter
    let viewController: SignInViewController
    let emailView: SignInView
    let codeView: SignInVerifyView

    var focusedCodeField: UITextField? {
        codeView.descendants(ofType: UITextField.self).first { $0.isFirstResponder }
    }
}

private final class UserWithoutEmail: RuuviUser {
    var apiKey: String?
    var email: String?
    var isAuthorized: Bool { apiKey != nil }
    func login(apiKey: String) { self.apiKey = apiKey }
    func logout() { apiKey = nil }
}

private extension UIView {
    func descendants<T: UIView>(ofType type: T.Type) -> [T] {
        subviews.flatMap { subview in
            [subview as? T].compactMap { $0 } + subview.descendants(ofType: type)
        }
    }
}
