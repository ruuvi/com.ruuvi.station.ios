import LightRoute
import UIKit

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

    func openTagSettings(ruuviTag: RuuviTagSensor, humidity: Double?, output: TagSettingsModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "TagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: TagSettingsModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag, humidity: humidity, output: output)
            })
    }

    func openWebTagSettings(webTag: WebTagRealm) {
        let factory = StoryboardFactory(storyboardName: "WebTagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: WebTagSettingsModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(webTag: webTag)
            })
    }
}
