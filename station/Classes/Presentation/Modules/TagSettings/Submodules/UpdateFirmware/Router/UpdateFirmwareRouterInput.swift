import Foundation
import RuuviOntology

protocol UpdateFirmwareRouterInput: AnyObject {
    func dismiss()
    func openDfuDevicesScanner(_ ruuviTag: RuuviTagSensor)
}
