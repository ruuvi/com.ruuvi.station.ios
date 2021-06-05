import Foundation
import RuuviOntology

protocol ShareModuleInput: AnyObject {
    func configure(sensor: RuuviTagSensor)
    func dismiss()
}
