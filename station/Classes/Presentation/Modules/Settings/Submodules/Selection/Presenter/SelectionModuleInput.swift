import Foundation

protocol SelectionModuleInput: AnyObject {
    func configure(viewModel: SelectionViewModel, output: SelectionModuleOutput?)
    func dismiss()
}
