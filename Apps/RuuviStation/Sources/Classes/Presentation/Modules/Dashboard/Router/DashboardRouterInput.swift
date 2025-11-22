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
        activeMenu: CardsMenuType,
        openSettings: Bool // Legacy flow support, we can remove this with new menu.
    )
    // Opens legacy settings. Can be removed when full settings is implemented in new menu.
    func openTagSettings(
        snapshot: RuuviTagCardSnapshot,
        ruuviTag: RuuviTagSensor,
        latestMeasurement: RuuviTagSensorRecord?,
        sensorSettings: SensorSettings?,
        output: LegacyTagSettingsModuleOutput
    )
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func openBackgroundSelectionView(ruuviTag: RuuviTagSensor)
    func openMyRuuviAccount()
    func openShare(for sensor: RuuviTagSensor)
    func openRemove(
      for sensor: RuuviTagSensor,
      output: SensorRemovalModuleOutput
    )
}
