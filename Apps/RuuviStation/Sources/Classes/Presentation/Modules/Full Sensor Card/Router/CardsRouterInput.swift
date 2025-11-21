import Foundation
import RuuviOntology

protocol CardsRouterInput {
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func openTagSettings(
        snapshot: RuuviTagCardSnapshot,
        ruuviTag: RuuviTagSensor,
        latestMeasurement: RuuviTagSensorRecord?,
        sensorSettings: SensorSettings?,
        output: LegacyTagSettingsModuleOutput
    )
    func dismiss()
}
