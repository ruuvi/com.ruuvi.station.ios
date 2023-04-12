import Foundation

protocol SignInPromoRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openSignIn(output: SignInModuleOutput)
}
