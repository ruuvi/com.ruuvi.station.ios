import Foundation

protocol SignInRouterInput {
    func dismiss(completion: (() -> Void)?)
}
extension SignInRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
