import Foundation
import RuuviOntology

protocol VisibilitySettingsModuleFactory {
    func create(
        snapshot: RuuviTagCardSnapshot,
        sensor: RuuviTagSensor,
        sensorSettings: SensorSettings?
    ) -> VisibilitySettingsViewController
}
