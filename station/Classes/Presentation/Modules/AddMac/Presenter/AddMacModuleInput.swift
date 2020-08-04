import Foundation

protocol AddMacModuleInput: class {
    func configure(output: AddMacModuleOutput, for provider: RuuviNetworkProvider)
    func dismiss(completion: (() -> Void)?)
}
