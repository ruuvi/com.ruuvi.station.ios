import Foundation
import RuuviOntology

protocol OffsetCorrectionModuleInput: AnyObject {
    func configure(type: OffsetCorrectionType, ruuviTag: RuuviTagSensor, sensorSettings: SensorSettings?)
}
