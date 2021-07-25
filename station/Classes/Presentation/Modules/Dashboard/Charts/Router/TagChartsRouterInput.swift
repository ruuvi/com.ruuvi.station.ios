import UIKit
import RuuviOntology
import RuuviVirtual

protocol TagChartsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openDiscover()
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openSignIn(output: SignInModuleOutput)
    func openMenu(output: MenuModuleOutput)
    func openTagSettings(
        ruuviTag: RuuviTagSensor,
        temperature: Temperature?,
        humidity: Humidity?,
        sensor: SensorSettings?,
        output: TagSettingsModuleOutput
    )
    func openWebTagSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    )
}
extension TagChartsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
