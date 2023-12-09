import Foundation
import RuuviOntology

protocol TagSettingsModuleInput: AnyObject {
    func configure(
        ruuviTag: RuuviTagSensor,
        latestMeasurement: RuuviTagSensorRecord?,
        sensorSettings: SensorSettings?
    )
    func configure(output: TagSettingsModuleOutput)
    func dismiss(completion: (() -> Void)?)
}
