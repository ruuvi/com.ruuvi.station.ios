import UIKit
import RuuviOntology
import RuuviVirtual

protocol TagChartsViewRouterInput {
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
        rssi: Int?,
        sensor: SensorSettings?,
        output: TagSettingsModuleOutput,
        scrollToAlert: Bool
    )
    func openWebTagSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    )
    func openMyRuuviAccount()
}
extension TagChartsViewRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
