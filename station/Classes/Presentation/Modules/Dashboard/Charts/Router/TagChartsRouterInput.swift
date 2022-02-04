import UIKit
import RuuviOntology
import RuuviVirtual

protocol TagChartsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openDiscover(output: DiscoverModuleOutput)
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openSignIn(output: SignInModuleOutput)
    func openMenu(output: MenuModuleOutput)
    // swiftlint:disable:next function_parameter_count
    func openTagSettings(
        ruuviTag: RuuviTagSensor,
        temperature: Temperature?,
        humidity: Humidity?,
        sensor: SensorSettings?,
        output: TagSettingsModuleOutput,
        scrollToAlert: Bool
    )
    func openWebTagSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?,
        scrollToAlert: Bool
    )
}
extension TagChartsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
