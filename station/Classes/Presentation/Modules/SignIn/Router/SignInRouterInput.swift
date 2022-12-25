import Foundation

protocol SignInRouterInput {
    func dismiss(completion: (() -> Void)?)
    func popViewController(animated: Bool)
    func openSignInPromoViewController(output: SignInPromoModuleOutput)
}

extension SignInRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
