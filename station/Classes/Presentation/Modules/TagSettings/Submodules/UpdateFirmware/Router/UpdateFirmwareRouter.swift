import Foundation
import LightRoute
import RuuviOntology

class UpdateFirmwareRouter: UpdateFirmwareRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openDfuDevicesScanner(_ ruuviTag: RuuviTagSensor) {
    }
}
