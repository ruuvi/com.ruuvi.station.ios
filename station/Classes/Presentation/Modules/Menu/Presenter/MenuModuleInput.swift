import Foundation

protocol MenuModuleInput: AnyObject {
    func configure(output: MenuModuleOutput)
    func dismiss()
}
