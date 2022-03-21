import Foundation
import RuuviOntology
import RuuviVirtual

protocol CardsRouterInput {
    func openMenu(output: MenuModuleOutput)
    func openDiscover()
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openSignIn(output: SignInModuleOutput)
    // swiftlint:disable:next function_parameter_count
    func openTagSettings(
        ruuviTag: RuuviTagSensor,
        temperature: Temperature?,
        humidity: Humidity?,
        sensorSettings: SensorSettings?,
        output: TagSettingsModuleOutput,
        scrollToAlert: Bool
    )
    func openVirtualSensorSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    )
    func openTagCharts()
}
