import Foundation
import RuuviOntology

protocol OwnerModuleInput: AnyObject {
    func configure(ruuviTag: RuuviTagSensor, mode: OwnershipMode)
}
