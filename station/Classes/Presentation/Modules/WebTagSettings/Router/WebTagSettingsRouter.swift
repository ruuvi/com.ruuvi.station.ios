import UIKit
import LightRoute
import RuuviOntology

class WebTagSettingsRouter: WebTagSettingsRouterInput {
    weak var transitionHandler: UIViewController!
    private var backgroundSelectionModule: BackgroundSelectionModuleInput?

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openLocationPicker(output: LocationPickerModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "LocationPicker")
        try! transitionHandler
            .forStoryboard(factory: factory, to: LocationPickerModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(output: output)
            })
    }

    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl, options: [:])
        }
    }

    func openBackgroundSelectionView(virtualSensor: VirtualTagSensor) {
        let factory: BackgroundSelectionModuleFactory = BackgroundSelectionModuleFactoryImpl()
        let module = factory.create(for: nil, virtualTag: virtualSensor)
        self.backgroundSelectionModule = module
        transitionHandler
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )
    }
}
