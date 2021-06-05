import Foundation
import LightRoute
import RuuviOntology

class DfuDevicesScannerRouter: DfuDevicesScannerRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openFlashFirmware(_ dfuDevice: DfuDevice) {
        let factory = StoryboardFactory(storyboardName: "DfuFlash")
        try! transitionHandler
            .forStoryboard(factory: factory, to: DfuFlashModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(dfuDevice: dfuDevice)
            })
    }
}
