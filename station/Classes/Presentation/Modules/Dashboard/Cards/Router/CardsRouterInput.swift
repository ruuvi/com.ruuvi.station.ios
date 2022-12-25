import Foundation
import RuuviOntology
import RuuviVirtual

protocol CardsRouterInput {
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func openTagSettings(
        ruuviTag: RuuviTagSensor,
        latestMeasurement: RuuviTagSensorRecord,
        sensorSettings: SensorSettings?,
        scrollToAlert: Bool,
        output: TagSettingsModuleOutput
    )
    func openVirtualSensorSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    )
    func dismiss()
}
