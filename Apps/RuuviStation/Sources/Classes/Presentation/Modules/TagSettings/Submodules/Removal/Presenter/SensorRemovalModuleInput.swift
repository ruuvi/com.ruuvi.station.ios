import Foundation
import RuuviOntology

protocol SensorRemovalModuleInput: AnyObject {
    func configure(
        ruuviTag: RuuviTagSensor,
        output: SensorRemovalModuleOutput
    )
    func dismiss(completion: (() -> Void)?)
}
