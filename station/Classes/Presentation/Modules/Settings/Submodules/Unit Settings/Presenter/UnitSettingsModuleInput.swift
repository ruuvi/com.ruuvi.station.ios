import Foundation

protocol UnitSettingsModuleInput: AnyObject {
    func configure(viewModel: UnitSettingsViewModel, output: UnitSettingsModuleOutput?)
    func dismiss()
}
