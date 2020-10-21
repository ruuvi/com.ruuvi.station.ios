import Foundation

protocol SignInRouterInput {
    func dismiss(completion: (() -> Void)?)
    func popViewController(animated: Bool)
    func openEmailConfirmation(output: SignInModuleOutput)
}
extension SignInRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
