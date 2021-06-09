import Foundation
import RuuviOntology

protocol DfuFlashRouterInput: AnyObject {
    func dismissToRoot()
    func openDfuDevicesScanner(_ ruuviTag: RuuviTagSensor)
}
