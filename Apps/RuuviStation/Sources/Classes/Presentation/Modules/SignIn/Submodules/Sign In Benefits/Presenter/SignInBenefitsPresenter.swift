import Foundation

class SignInBenefitsPresenter: NSObject {
    weak var view: SignInBenefitsViewInput!
    var output: SignInBenefitsModuleOutput?
    var router: SignInBenefitsRouterInput!
}

// MARK: - SignInViewOutput

extension SignInBenefitsPresenter: SignInBenefitsViewOutput {
    func viewDidLoad() {
        // No op.
    }

    func viewDidTapClose() {
        output?.signIn(module: self, didCloseSignInWithoutAttempt: nil)
    }

    func viewDidTapContinue() {
        router.openSignIn(output: self)
    }
}

// MARK: - SignInPromoModuleInput

extension SignInBenefitsPresenter: SignInBenefitsModuleInput {
    func configure(output: SignInBenefitsModuleOutput?) {
        self.output = output
    }

    func dismiss(completion: (() -> Void)?) {
        router.dismiss(completion: completion)
    }
}

extension SignInBenefitsPresenter: SignInModuleOutput {
    func signIn(module: SignInModuleInput, didSuccessfulyLogin sender: Any?) {
        module.dismiss(completion: { [weak self] in
            guard let self else { return }
            output?.signIn(module: self, didSuccessfulyLogin: sender)
        })
    }

    func signIn(module: SignInModuleInput, didCloseSignInWithoutAttempt sender: Any?) {
        module.dismiss(completion: { [weak self] in
            guard let self else { return }
            output?.signIn(module: self, didCloseSignInWithoutAttempt: sender)
        })
    }

    func signIn(module: SignInModuleInput, didSelectUseWithoutAccount sender: Any?) {
        module.dismiss(completion: { [weak self] in
            guard let self else { return }
            output?.signIn(module: self, didSelectUseWithoutAccount: sender)
        })
    }
}
