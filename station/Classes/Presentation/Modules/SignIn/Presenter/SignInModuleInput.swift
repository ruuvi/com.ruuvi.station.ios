import Foundation

protocol SignInModuleInput: class {
    func configure(with state: SignInPresenter.State, output: SignInModuleOutput?)
    func dismiss()
}
