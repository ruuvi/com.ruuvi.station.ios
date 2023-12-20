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
    func openCardImageView(
        with viewModels: [CardsViewModel],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        scrollTo: CardsViewModel?,
        showCharts: Bool,
        output: CardsModuleOutput
    )
    func openTagSettings(
        ruuviTag: RuuviTagSensor,
        latestMeasurement: RuuviTagSensorRecord?,
        sensorSettings: SensorSettings?,
        output: TagSettingsModuleOutput
    )
    // swiftlint:disable function_parameter_count
    /// Used for only when a new sensor is added.
    func openTagSettings(
        with viewModels: [CardsViewModel],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        scrollTo: CardsViewModel?,
        ruuviTag: RuuviTagSensor,
        latestMeasurement: RuuviTagSensorRecord?,
        sensorSetting: SensorSettings?,
        output: CardsModuleOutput
    )
    // swiftlint:enable function_parameter_count
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func openBackgroundSelectionView(ruuviTag: RuuviTagSensor)
    func openMyRuuviAccount()
    func openShare(for sensor: RuuviTagSensor)
}
