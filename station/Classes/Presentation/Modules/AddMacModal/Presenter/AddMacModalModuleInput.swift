import Foundation

protocol AddMacModalModuleInput: class {
    func configure(output: AddMacModalModuleOutput, for provider: RuuviNetworkProvider)
    func dismiss()
}
