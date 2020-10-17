import Foundation

protocol SignInModuleInput: class {
    func configure(output: SignInModuleOutput)
    func dismiss()
}
