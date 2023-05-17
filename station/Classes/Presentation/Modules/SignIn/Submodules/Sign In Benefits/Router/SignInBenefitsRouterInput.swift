import Foundation

protocol SignInBenefitsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openSignIn(output: SignInModuleOutput)
}
