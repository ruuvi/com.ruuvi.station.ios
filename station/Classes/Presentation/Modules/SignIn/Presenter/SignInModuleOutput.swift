protocol SignInModuleOutput: AnyObject {
    func signIn(module: SignInModuleInput, didSuccessfulyLogin sender: Any?)
}
