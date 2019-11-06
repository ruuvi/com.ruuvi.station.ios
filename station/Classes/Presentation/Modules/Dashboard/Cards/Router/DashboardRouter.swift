import LightRoute

class DashboardRouter: NSObject, DashboardRouterInput {
    weak var transitionHandler: UIViewController!
    weak var delegate: DashboardRouterDelegate!
    weak var tagCharts: UIViewController!
    var settings: Settings!
    
    var menuTableInteractiveTransition: MenuTableTransitioningDelegate!
    var tagChartsTransitioningDelegate: TagChartsTransitioningDelegate!
    
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
    
    func openDiscover() {
        let restorationId = "DiscoverTableNavigationController"
        let factory = StoryboardFactory(storyboardName: "Discover", bundle: .main, restorationId: restorationId)
        try! transitionHandler
            .forStoryboard(factory: factory, to: DiscoverModuleInput.self)
            .apply(to: { (viewController) in
                viewController.presentationController?.delegate = self
            })
            .then({ (module) -> Any? in
                module.configure(isOpenedFromWelcome: false)
            })
    }
    
    func openSettings() {
        let factory = StoryboardFactory(storyboardName: "Settings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: SettingsModuleInput.self)
            .perform()
    }
    
    func openTagSettings(ruuviTag: RuuviTagRealm, humidity: Double?) {
        let factory = StoryboardFactory(storyboardName: "TagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: TagSettingsModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag, humidity: humidity)
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
    
}

extension DashboardRouter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return delegate.shouldDismissDiscover()
    }
}
