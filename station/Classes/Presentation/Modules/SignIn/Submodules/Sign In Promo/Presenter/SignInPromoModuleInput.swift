import Foundation

protocol SignInPromoModuleInput: AnyObject {
    func configure(output: SignInPromoModuleOutput?)
    func dismiss(completion: (() -> Void)?)
}
