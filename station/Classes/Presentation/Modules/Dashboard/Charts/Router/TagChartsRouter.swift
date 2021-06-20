import LightRoute
import UIKit
import RuuviOntology
import RuuviVirtual

class TagChartsRouter: TagChartsRouterInput {
    weak var transitionHandler: UIViewController!

    private var menuTableTransition: MenuTableTransitioningDelegate!

    func dismiss(completion: (() -> Void)? = nil) {
        transitionHandler.dismiss(animated: true, completion: completion)
    }

    func openMenu(output: MenuModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "Menu")
        try! transitionHandler
            .forStoryboard(factory: factory, to: MenuModuleInput.self)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
                let manager = MenuTableTransitionManager(container: self.transitionHandler, menu: viewController)
                self.menuTableTransition = MenuTableTransitioningDelegate(manager: manager)
            })
            .add(transitioningDelegate: menuTableTransition)
            .then({ (module) -> Any? in
                module.configure(output: output)
            })
    }

    func openSettings() {
        let factory = StoryboardFactory(storyboardName: "Settings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: SettingsModuleInput.self)
            .perform()
    }

    func openDiscover(output: DiscoverModuleOutput) {
        let restorationId = "DiscoverTableNavigationController"
        let factory = StoryboardFactory(storyboardName: "Discover", bundle: .main, restorationId: restorationId)
        try! transitionHandler
            .forStoryboard(factory: factory, to: DiscoverModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(isOpenedFromWelcome: false, output: output)
            })
    }

    func openAbout() {
        let factory = StoryboardFactory(storyboardName: "About")
        try! transitionHandler
            .forStoryboard(factory: factory, to: AboutModuleInput.self)
            .perform()
    }

    func openRuuviWebsite() {
        UIApplication.shared.open(URL(string: "https://ruuvi.com")!, options: [:], completionHandler: nil)
    }

    func openTagSettings(ruuviTag: RuuviTagSensor,
                         temperature: Temperature?,
                         humidity: Humidity?,
                         sensor: SensorSettings?,
                         output: TagSettingsModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "TagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: TagSettingsModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag,
                                 temperature: temperature,
                                 humidity: humidity,
                                 sensor: sensor,
                                 output: output)
            })
    }

    func openWebTagSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    ) {
        let factory = StoryboardFactory(storyboardName: "WebTagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: WebTagSettingsModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(sensor: sensor, temperature: temperature)
            })
    }

    func openSignIn(output: SignInModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "SignIn")
        try! transitionHandler
            .forStoryboard(factory: factory, to: SignInModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(with: .enterEmail, output: output)
            })
    }

    func macCatalystExportFile(with path: URL, delegate: UIDocumentPickerDelegate?) {
        let controller = UIDocumentPickerViewController(url: path, in: .exportToService)
        controller.delegate = delegate
        transitionHandler.present(controller, animated: true)
    }
}
