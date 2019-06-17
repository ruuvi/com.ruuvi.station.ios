import Foundation

protocol MenuModuleInput: class {
    func configure(output: MenuModuleOutput)
    func dismiss()
}
