import Foundation

protocol DiscoverModuleInput: AnyObject {
    func configure(isOpenedFromWelcome: Bool, output: DiscoverModuleOutput?)
    func dismiss(completion: (() -> Void)?)
}

extension DiscoverModuleInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
