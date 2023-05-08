import Foundation

protocol SignInRouterInput {
    func dismiss(completion: (() -> Void)?)
    func popViewController(animated: Bool, completion: (() -> Void)?)
    func openSignInPromoViewController(output: SignInBenefitsModuleOutput)
}

extension SignInRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
