import Foundation

protocol SignInModuleInput: AnyObject {
    func configure(with state: SignInPresenter.State,
                   output: SignInModuleOutput?)
    func dismiss()
}
