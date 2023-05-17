import Foundation

protocol SignInBenefitsModuleOutput: AnyObject {
    func signIn(module: SignInBenefitsModuleInput,
                didCloseSignInWithoutAttempt sender: Any?)
    func signIn(module: SignInBenefitsModuleInput,
                didSelectUseWithoutAccount sender: Any?)
    func signIn(module: SignInBenefitsModuleInput,
                didSuccessfulyLogin sender: Any?)
}
