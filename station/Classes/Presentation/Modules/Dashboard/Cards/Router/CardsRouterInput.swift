import Foundation

protocol CardsRouterInput {
    func openMenu(output: MenuModuleOutput)
    func openDiscover(output: DiscoverModuleOutput)
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openTagSettings(ruuviTag: RuuviTagRealm, humidity: Double?)
    func openWebTagSettings(webTag: WebTagRealm)
    func openTagCharts()
}
