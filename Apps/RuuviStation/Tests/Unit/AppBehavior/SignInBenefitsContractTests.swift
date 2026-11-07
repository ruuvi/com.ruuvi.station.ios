import XCTest
@testable import station

@MainActor final class SignInBenefitsContractTests: XCTestCase {
    func testContinueAndCloseRouteOnceAndPreserveTheBenefitsModuleIdentity() {
        let presenter = SignInBenefitsPresenter()
        let router = BenefitsRouterSpy()
        let output = BenefitsOutputSpy()
        presenter.router = router
        presenter.configure(output: output)
        presenter.viewDidLoad()
        XCTAssertTrue(output.events.isEmpty)
        presenter.viewDidTapContinue()
        XCTAssertTrue(router.output === presenter)
        presenter.viewDidTapClose()
        XCTAssertEqual(output.events, ["close"])
        XCTAssertTrue(output.module === presenter)
        XCTAssertNil(output.sender)
        var completions = 0
        presenter.dismiss { completions += 1 }
        XCTAssertEqual(router.dismissals, 1)
        XCTAssertEqual(completions, 1)
    }

    func testSignInOutcomesWaitForChildDismissalAndKeepTheSender() {
        for outcome in ["success", "close", "offline"] {
            let presenter = SignInBenefitsPresenter()
            let output = BenefitsOutputSpy()
            let child = BenefitsSignInSpy()
            let sender = NSObject()
            presenter.configure(output: output)
            switch outcome {
            case "success": presenter.signIn(module: child, didSuccessfulyLogin: sender)
            case "close": presenter.signIn(module: child, didCloseSignInWithoutAttempt: sender)
            default: presenter.signIn(module: child, didSelectUseWithoutAccount: sender)
            }
            XCTAssertEqual(child.dismissals, 1)
            XCTAssertTrue(output.events.isEmpty)
            child.finish?()
            XCTAssertEqual(output.events, [outcome])
            XCTAssertTrue(output.module === presenter)
            XCTAssertTrue(output.sender === sender)
        }
    }

    func testLateChildDismissalCannotRetainOrNotifyAReleasedBenefitsPresenter() {
        let output = BenefitsOutputSpy()
        let child = BenefitsSignInSpy()
        var presenter: SignInBenefitsPresenter? = SignInBenefitsPresenter()
        presenter?.configure(output: output)
        presenter?.signIn(module: child, didSuccessfulyLogin: nil)
        weak var released = presenter
        presenter = nil
        XCTAssertNil(released)
        child.finish?()
        XCTAssertTrue(output.events.isEmpty)
    }
}
private final class BenefitsRouterSpy: SignInBenefitsRouterInput {
    weak var output: SignInModuleOutput?
    var dismissals = 0
    func dismiss(completion: (() -> Void)?) { dismissals += 1; completion?() }
    func openSignIn(output: SignInModuleOutput) { self.output = output }
}
private final class BenefitsSignInSpy: SignInModuleInput {
    var dismissals = 0
    var finish: (() -> Void)?
    func configure(with state: SignInPresenter.State, output: SignInModuleOutput?) {}
    func dismiss(completion: (() -> Void)?) { dismissals += 1; finish = completion }
}
private final class BenefitsOutputSpy: SignInBenefitsModuleOutput {
    var events = [String]()
    weak var module: SignInBenefitsModuleInput?
    var sender: NSObject?
    func signIn(module: SignInBenefitsModuleInput, didCloseSignInWithoutAttempt sender: Any?) {
        record("close", module, sender)
    }
    func signIn(module: SignInBenefitsModuleInput, didSelectUseWithoutAccount sender: Any?) {
        record("offline", module, sender)
    }
    func signIn(module: SignInBenefitsModuleInput, didSuccessfulyLogin sender: Any?) {
        record("success", module, sender)
    }
    private func record(_ event: String, _ module: SignInBenefitsModuleInput, _ sender: Any?) {
        events.append(event); self.module = module; self.sender = sender as? NSObject
    }
}
