import Foundation

protocol UnitSettingsRouterInput {
    func dismiss()
    func openSelection(with viewModel: SelectionViewModel, output: SelectionModuleOutput?)
}
