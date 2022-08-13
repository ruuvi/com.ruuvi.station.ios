import Foundation
import RuuviOntology
import RuuviVirtual

protocol CardsRouterInput {
    func openMenu(output: MenuModuleOutput)
    func openDiscover()
    func openSettings()
    func openAbout()
    func openWhatToMeasurePage()
    func openRuuviProductsPage()
    func openRuuviGatewayPage()
    func openSignIn(output: SignInModuleOutput)
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    // swiftlint:disable:next function_parameter_count
    func openTagSettings(
        ruuviTag: RuuviTagSensor,
        temperature: Temperature?,
        humidity: Humidity?,
        rssi: Int?,
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
