import Foundation
import LightRoute
import RuuviOntology

class DfuFlashRouter: DfuFlashRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismissToRoot() {
        try! transitionHandler
            .closeCurrentModule()
            .find(pop: { controller in
                return controller is TagSettingsTableViewController
            })
            .preferred(style: .navigation(style: .findedPop))
            .perform()
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
