import Foundation

protocol SettingsRouterInput {
    func dismiss()
    func openLanguage()
    func openDefaults()
    func openHeartbeat()
    func openChart()
    func openFeatureToggles()
    func openSelection(with viewModel: SelectionViewModel, output: SelectionModuleOutput?)
}
