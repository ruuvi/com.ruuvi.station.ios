import Foundation

protocol SettingsRouterInput {
    func dismiss()
    func openLanguage()
    func openForeground()
    func openDefaults()
    func openHeartbeat()
    func openAdvanced()
    func openNetworkSettings()
    func openSelection(with viewModel: SelectionViewModel, output: SelectionModuleOutput?)
}
