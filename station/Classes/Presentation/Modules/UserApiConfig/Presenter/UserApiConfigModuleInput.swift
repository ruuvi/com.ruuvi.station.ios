import Foundation

protocol UserApiConfigModuleInput: class {
    func configure(output: UserApiConfigModuleOutput)
    func dismiss()
}
