import Foundation
import RuuviOntology

protocol DFUModuleInput: AnyObject {
    func configure(ruuviTag: RuuviTagSensor)
}
