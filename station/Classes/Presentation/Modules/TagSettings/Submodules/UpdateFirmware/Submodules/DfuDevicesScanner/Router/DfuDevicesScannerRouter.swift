import Foundation
import LightRoute
import RuuviOntology

class DfuDevicesScannerRouter: DfuDevicesScannerRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openFlashFirmware(_ dfuDevice: DfuDevice) {
    }
}
