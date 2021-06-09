import Foundation
import RuuviOntology

protocol DfuDevicesScannerModuleInput: AnyObject {
    func configure(ruuviTag: RuuviTagSensor)
}
