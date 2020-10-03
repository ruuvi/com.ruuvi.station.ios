import Foundation

protocol SelectionModuleInput: class {
    func configure(viewModel: SelectionViewModel, output: SelectionModuleOutput?)
    func dismiss()
}
