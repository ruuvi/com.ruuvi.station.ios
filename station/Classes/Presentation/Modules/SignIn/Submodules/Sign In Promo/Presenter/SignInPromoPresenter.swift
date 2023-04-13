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

    func viewDidTapContinue() {
        router.openSignIn(output: self)
    }
}

// MARK: - SignInPromoModuleInput
extension SignInPromoPresenter: SignInPromoModuleInput {
    func configure(output: SignInPromoModuleOutput?) {
        self.output = output
    }

    func dismiss(completion: (() -> Void)?) {
        router.dismiss(completion: completion)
    }
}

extension SignInPromoPresenter: SignInModuleOutput {
    func signIn(module: SignInModuleInput, didSuccessfulyLogin sender: Any?) {
        module.dismiss(completion: { [weak self] in
            guard let self = self else { return }
            self.output?.signIn(module: self, didSuccessfulyLogin: sender)
        })
    }

    func signIn(module: SignInModuleInput, didCloseSignInWithoutAttempt sender: Any?) {
        module.dismiss(completion: { [weak self] in
            guard let self = self else { return }
            self.output?.signIn(module: self, didCloseSignInWithoutAttempt: sender)
        })
    }

    func signIn(module: SignInModuleInput, didSelectUseWithoutAccount sender: Any?) {
        module.dismiss(completion: { [weak self] in
            guard let self = self else { return }
            self.output?.signIn(module: self, didSelectUseWithoutAccount: sender)
        })
    }
}
