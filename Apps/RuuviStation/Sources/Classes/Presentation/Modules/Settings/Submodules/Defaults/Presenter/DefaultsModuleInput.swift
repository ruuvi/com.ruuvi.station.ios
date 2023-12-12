import Foundation

protocol DefaultsModuleInput: AnyObject {
    func configure(output: DefaultsModuleOutput)
    func dismiss(completion: (() -> Void)?)
}
