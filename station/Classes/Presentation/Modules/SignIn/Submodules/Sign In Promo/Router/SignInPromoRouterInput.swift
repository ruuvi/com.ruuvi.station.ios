import Foundation

protocol SignInPromoRouterInput {
    func dismiss(completion: (() -> Void)?)
    func popViewController(animated: Bool)
}

extension SignInPromoRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
