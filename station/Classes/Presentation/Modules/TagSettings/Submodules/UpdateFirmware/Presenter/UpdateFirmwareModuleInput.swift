import Foundation
import RuuviOntology

protocol UpdateFirmwareModuleInput: AnyObject {
    func configure(ruuviTag: RuuviTagSensor)
}
