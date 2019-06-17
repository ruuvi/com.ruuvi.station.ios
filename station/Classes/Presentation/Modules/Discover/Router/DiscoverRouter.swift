import LightRoute
import BTKit

class DiscoverRouter: DiscoverRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    private lazy var ruuviTagAddTransitioningDelegate = RuuviTagAddTransitioningDelegate()
    
    func open(ruuviTag: RuuviTag) {
        let factory = StoryboardFactory(storyboardName: "RuuviTag")
        try! transitionHandler
            .forStoryboard(factory: factory, to: RuuviTagModuleInput.self)
            .add(transitioningDelegate: ruuviTagAddTransitioningDelegate)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
            })
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag)
            })
    }
    
    func openDashboard() {
        let factory = StoryboardFactory(storyboardName: "Dashboard")
        try! transitionHandler
            .forStoryboard(factory: factory, to: DashboardModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .perform()
    }
    
    func openRuuviWebsite() {
        UIApplication.shared.open(URL(string: "https://ruuvi.com")!, options: [:], completionHandler: nil)
    }
    
    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
