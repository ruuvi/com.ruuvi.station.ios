import Foundation
import RuuviOntology

protocol SensorRemovalModuleOutput: AnyObject {
    func sensorRemovalDidRemoveTag(
        module: SensorRemovalModuleInput,
        ruuviTag: RuuviTagSensor
    )
    func sensorRemovalDidDismiss(module: SensorRemovalModuleInput)
}
