import LightRoute
import BTKit

class DiscoverRouter: DiscoverRouterInput {
    weak var transitionHandler: TransitionHandler!
    
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
