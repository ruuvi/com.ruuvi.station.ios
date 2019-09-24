import Foundation

protocol TagChartsRouterInput {
    func dismiss()
    func openDiscover()
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openMenu(output: MenuModuleOutput)
}
