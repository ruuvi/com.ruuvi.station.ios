import Foundation

protocol SignInPromoModuleOutput: AnyObject {
    func signIn(module: SignInPromoModuleInput,
                didSelectUseWithoutAccount sender: Any?)
}
