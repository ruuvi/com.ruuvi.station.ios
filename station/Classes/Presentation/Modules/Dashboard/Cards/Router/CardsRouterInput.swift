import Foundation
import RuuviOntology
import RuuviVirtual

protocol CardsRouterInput {
    func openMenu(output: MenuModuleOutput)
    func openDiscover(output: DiscoverModuleOutput)
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openSignIn(output: SignInModuleOutput)
    func openTagSettings(
        ruuviTag: RuuviTagSensor,
        temperature: Temperature?,
        humidity: Humidity?,
        sensorSettings: SensorSettings?,
        output: TagSettingsModuleOutput
    )
    func openVirtualSensorSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    )
    func openTagCharts()
}
