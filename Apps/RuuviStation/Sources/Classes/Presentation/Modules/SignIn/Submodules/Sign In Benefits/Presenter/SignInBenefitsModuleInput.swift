import Foundation

protocol SignInBenefitsModuleInput: AnyObject {
    func configure(output: SignInBenefitsModuleOutput?)
    func dismiss(completion: (() -> Void)?)
}
