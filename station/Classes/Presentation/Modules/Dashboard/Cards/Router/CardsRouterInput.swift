import Foundation

protocol CardsRouterInput {
    func openMenu(output: MenuModuleOutput)
    func openDiscover(output: DiscoverModuleOutput)
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openTagSettings(ruuviTag: RuuviTagSensor,
                         temperature: Temperature?,
                         humidity: Humidity?,
                         sensorSettings: SensorSettings?,
                         output: TagSettingsModuleOutput)
    func openWebTagSettings(webTag: WebTagRealm,
                            temperature: Temperature?)
    func openTagCharts()
}
