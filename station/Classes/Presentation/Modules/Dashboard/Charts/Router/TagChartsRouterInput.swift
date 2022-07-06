import UIKit
import RuuviOntology
import RuuviVirtual

protocol TagChartsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openDiscover()
    func openSettings()
    func openAbout()
    func openWhatToMeasurePage()
    func openRuuviProductsPage()
    func openRuuviGatewayPage()
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
        temperature: Temperature?
    )
}
extension TagChartsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
