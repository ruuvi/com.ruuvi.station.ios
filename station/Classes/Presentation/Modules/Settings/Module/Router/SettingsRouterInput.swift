import Foundation

protocol SettingsRouterInput {
    func dismiss()
    func openLanguage()
    func openForeground()
    func openDefaults()
    func openHeartbeat()
    func openAdvanced()
    func openPressureSelection(withDataSource items: [UnitPressure], title: String, output: SelectionModuleOutput?)
}
