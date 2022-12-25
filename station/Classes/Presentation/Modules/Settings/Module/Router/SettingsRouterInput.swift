import Foundation

protocol SettingsRouterInput {
    func dismiss()
    func openDefaults()
    func openDevices()
    func openHeartbeat()
    func openChart()
    func openFeatureToggles()
    func openUnitSettings(with viewModel: UnitSettingsViewModel, output: UnitSettingsModuleOutput?)
    func openRuuviCloud()
}
