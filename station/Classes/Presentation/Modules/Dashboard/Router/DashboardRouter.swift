import LightRoute

class DashboardRouter: DashboardRouterInput {
    weak var transitionHandler: TransitionHandler!
    var settings: Settings!
    
    var menuTableInteractiveTransition: MenuTableTransitioningDelegate!
    
    private lazy var chartTransitioningDelegate = ChartTransitioningDelegate()
    private var menuTableTransition: MenuTableTransitioningDelegate!
    private lazy var humidityCalibrationTransitioningDelegate = HumidityCalibrationTransitioningDelegate()
    
    func openChart(ruuviTag: RuuviTagRealm, type: ChartDataType) {
        let factory = StoryboardFactory(storyboardName: "Chart")
        try! transitionHandler
            .forStoryboard(factory: factory, to: ChartModuleInput.self)
            .add(transitioningDelegate: chartTransitioningDelegate)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
            }).then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag, type: type)
            })
    }
    
    func openMenu(output: MenuModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "Menu")
        try! transitionHandler
            .forStoryboard(factory: factory, to: MenuModuleInput.self)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
                let manager = MenuTableTransitionManager(container: self.transitionHandler as! UIViewController, menu: viewController)
                self.menuTableTransition = MenuTableTransitioningDelegate(manager: manager)
            })
            .add(transitioningDelegate: menuTableTransition)
            .then({ (module) -> Any? in
                module.configure(output: output)
            })
    }
    
    func openDiscover() {
        let restorationId = settings.experimentalUX ? "DiscoverPulsatorViewController" : "DiscoverTableNavigationController"
        let factory = StoryboardFactory(storyboardName: "Discover", bundle: .main, restorationId: restorationId)
        try! transitionHandler
            .forStoryboard(factory: factory, to: DiscoverModuleInput.self)
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
    
    func openAbout() {
        let factory = StoryboardFactory(storyboardName: "About")
        try! transitionHandler
            .forStoryboard(factory: factory, to: AboutModuleInput.self)
            .perform()
    }
    
    func openRuuviWebsite() {
        UIApplication.shared.open(URL(string: "https://ruuvi.com")!, options: [:], completionHandler: nil)
    }
    
    func openHumidityCalibration(ruuviTag: RuuviTagRealm) {
        let factory = StoryboardFactory(storyboardName: "HumidityCalibration")
        try! transitionHandler
            .forStoryboard(factory: factory, to: HumidityCalibrationModuleInput.self)
            .add(transitioningDelegate: humidityCalibrationTransitioningDelegate)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
            })
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag)
            })
    }
}
