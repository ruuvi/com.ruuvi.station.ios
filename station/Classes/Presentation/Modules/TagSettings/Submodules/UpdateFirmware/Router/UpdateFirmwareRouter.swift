import Foundation
import LightRoute
import RuuviOntology

class UpdateFirmwareRouter: UpdateFirmwareRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openDfuDevicesScanner(_ ruuviTag: RuuviTagSensor) {
        let factory = StoryboardFactory(storyboardName: "DfuDevicesScanner")
        try! transitionHandler
            .forStoryboard(factory: factory, to: DfuDevicesScannerModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag)
            })
    }
}
