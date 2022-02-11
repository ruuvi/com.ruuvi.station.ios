import Foundation

protocol SettingsRouterInput {
    func dismiss()
    func openLanguage()
    func openDefaults()
    func openHeartbeat()
    func openAdvanced()
    func openFeatureToggles()
    func openSelection(with viewModel: SelectionViewModel, output: SelectionModuleOutput?)
}
