import UIKit

protocol TagChartsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openDiscover(output: DiscoverModuleOutput)
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openSignIn(output: SignInModuleOutput)
    func openUserApiConfig(output: UserApiConfigModuleOutput)
    func openMenu(output: MenuModuleOutput)
    func openTagSettings(ruuviTag: RuuviTagSensor,
                         temperature: Temperature?,
                         humidity: Humidity?,
                         output: TagSettingsModuleOutput)
    func openWebTagSettings(webTag: WebTagRealm,
                            temperature: Temperature?)
    func macCatalystExportFile(with path: URL, delegate: UIDocumentPickerDelegate?)
}
extension TagChartsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
