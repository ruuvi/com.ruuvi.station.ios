import Foundation
import RuuviOntology

protocol LegacyTagSettingsModuleInput: AnyObject {
    func configure(
        ruuviTag: RuuviTagSensor,
        latestMeasurement: RuuviTagSensorRecord?,
        sensorSettings: SensorSettings?
    )
    func configure(output: LegacyTagSettingsModuleOutput)
    func dismiss(completion: (() -> Void)?)
}
