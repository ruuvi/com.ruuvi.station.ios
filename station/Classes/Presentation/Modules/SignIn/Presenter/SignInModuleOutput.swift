protocol SignInModuleOutput: AnyObject {
    func signIn(module: SignInModuleInput, didSuccessfulyLogin sender: Any?)
    func signIn(module: SignInModuleInput, didCloseSignInWithoutAttempt sender: Any?)
    func signIn(module: SignInModuleInput, didSelectUseWithoutAccount sender: Any?)
}
