import UIKit

protocol TagChartsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openDiscover(output: DiscoverModuleOutput)
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openMenu(output: MenuModuleOutput)
    func openTagSettings(ruuviTag: RuuviTagSensor, humidity: Double?, output: TagSettingsModuleOutput)
    func openWebTagSettings(webTag: WebTagRealm)
    func macCatalystExportFile(with path: URL, delegate: UIDocumentPickerDelegate?)
}
extension TagChartsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
