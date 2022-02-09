import LightRoute
import Foundation
import UIKit
import RuuviOntology
import RuuviLocal
import RuuviVirtual

class CardsRouter: NSObject, CardsRouterInput {
    weak var transitionHandler: UIViewController!
    weak var delegate: CardsRouterDelegate!
    weak var tagCharts: UIViewController!
    var settings: RuuviLocalSettings!

    // swiftlint:disable weak_delegate
    var menuTableInteractiveTransition: MenuTableTransitioningDelegate!
    var tagChartsTransitioningDelegate: TagChartsTransitioningDelegate!
    // swiftlint:enable weak_delegate

    private var menuTableTransition: MenuTableTransitioningDelegate!

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

    func openDiscover(output: DiscoverModuleOutput) {
        let restorationId = "DiscoverTableNavigationController"
        let factory = StoryboardFactory(storyboardName: "Discover", bundle: .main, restorationId: restorationId)
        try! transitionHandler
            .forStoryboard(factory: factory, to: DiscoverModuleInput.self)
            .apply(to: { (viewController) in
                viewController.presentationController?.delegate = self
            })
            .then({ (module) -> Any? in
                module.configure(isOpenedFromWelcome: false, output: output)
            })
    }

    func openSettings() {
        let factory = StoryboardFactory(storyboardName: "Settings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: SettingsModuleInput.self)
            .perform()
    }

    // swiftlint:disable:next function_parameter_count
    func openTagSettings(ruuviTag: RuuviTagSensor,
                         temperature: Temperature?,
                         humidity: Humidity?,
                         sensorSettings: SensorSettings?,
                         output: TagSettingsModuleOutput,
                         scrollToAlert: Bool) {
        let factory = StoryboardFactory(storyboardName: "TagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: TagSettingsModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag,
                                 temperature: temperature,
                                 humidity: humidity,
                                 sensor: sensorSettings,
                                 output: output,
                                 scrollToAlert: scrollToAlert)
            })
    }

    func openVirtualSensorSettings(
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

    func openAbout() {
        let factory = StoryboardFactory(storyboardName: "About")
        try! transitionHandler
            .forStoryboard(factory: factory, to: AboutModuleInput.self)
            .perform()
    }

    func openTagCharts() {
        transitionHandler.present(tagCharts, animated: true)
    }

    func openRuuviWebsite() {
        UIApplication.shared.open(URL(string: "https://ruuvi.com")!, options: [:], completionHandler: nil)
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

extension CardsRouter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return delegate.shouldDismissDiscover()
    }
}
