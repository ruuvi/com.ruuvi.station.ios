import Foundation
import RuuviOntology

protocol SensorForceClaimModuleInput: AnyObject {
    func configure(ruuviTag: RuuviTagSensor)
}
