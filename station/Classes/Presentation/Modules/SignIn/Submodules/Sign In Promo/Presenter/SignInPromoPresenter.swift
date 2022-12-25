import Foundation

class SignInPromoPresenter: NSObject {
    weak var view: SignInPromoViewInput!
    var output: SignInPromoModuleOutput?
    var router: SignInPromoRouterInput!
}
// MARK: - SignInViewOutput
extension SignInPromoPresenter: SignInPromoViewOutput {
    func viewDidLoad() {
        // No op.
    }

    func viewDidTapLetsDoIt() {
        router.popViewController(animated: true)
    }

    func viewDidTapUseWithoutAccount() {
        output?.signIn(module: self,
                       didSelectUseWithoutAccount: nil)
    }
}

// MARK: - SignInPromoModuleInput
extension SignInPromoPresenter: SignInPromoModuleInput {
    func configure(output: SignInPromoModuleOutput?) {
        self.output = output
    }

    func dismiss(completion: (() -> Void)?) {
        router.popViewController(animated: false)
        completion?()
    }
}
