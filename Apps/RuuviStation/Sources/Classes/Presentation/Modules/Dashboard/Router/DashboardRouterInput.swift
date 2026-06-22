import Foundation
import RuuviOntology

protocol DashboardRouterInput {
    func openMenu(output: MenuModuleOutput)
    func openDiscover(delegate: DiscoverRouterDelegate)
    func openSettings()
    func openAbout()
    func openWhatToMeasurePage()
    func openRuuviProductsPage()
    func openRuuviProductsPageFromMenu()
    func openSignIn(output: SignInBenefitsModuleOutput)
    // swiftlint:disable:next function_parameter_count
    func openFullSensorCard(
        for snapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        activeMenu: CardsMenuType
    )
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func openMyRuuviAccount()
    func openRemove(
      for sensor: RuuviTagSensor,
      output: SensorRemovalModuleOutput
    )
}
