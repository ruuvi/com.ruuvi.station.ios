import Foundation

protocol SignInPromoModuleOutput: AnyObject {
    func signIn(module: SignInPromoModuleInput,
                didCloseSignInWithoutAttempt sender: Any?)
    func signIn(module: SignInPromoModuleInput,
                didSelectUseWithoutAccount sender: Any?)
    func signIn(module: SignInPromoModuleInput,
                didSuccessfulyLogin sender: Any?)
}
