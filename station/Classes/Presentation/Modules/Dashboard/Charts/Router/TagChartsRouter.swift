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

    func openDiscover() {
        let discoverRouter = DiscoverRouter()
        discoverRouter.delegate = self
        let viewController = discoverRouter.viewController
        let navigationController = UINavigationController(rootViewController: viewController)
        transitionHandler.present(navigationController, animated: true)
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

    // swiftlint:disable:next function_parameter_count
    func openTagSettings(ruuviTag: RuuviTagSensor,
                         temperature: Temperature?,
                         humidity: Humidity?,
                         sensor: SensorSettings?,
                         output: TagSettingsModuleOutput,
                         scrollToAlert: Bool) {
        let factory = StoryboardFactory(storyboardName: "TagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: TagSettingsModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag,
                                 temperature: temperature,
                                 humidity: humidity,
                                 sensor: sensor,
                                 output: output,
                                 scrollToAlert: scrollToAlert)
            })
    }

    func openWebTagSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?,
        scrollToAlert: Bool
    ) {
        let factory = StoryboardFactory(storyboardName: "WebTagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: WebTagSettingsModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(sensor: sensor, temperature: temperature, scrollToAlert: scrollToAlert)
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
}

extension TagChartsRouter: DiscoverRouterDelegate {
    func discoverRouterWantsClose(_ router: DiscoverRouter) {
        router.viewController.dismiss(animated: true) { [weak self] in
            self?.dismiss()
        }
    }
}
