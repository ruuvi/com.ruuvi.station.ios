import LightRoute

class WelcomeRouter: WelcomeRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    func openDiscover() {
        let factory = StoryboardFactory(storyboardName: "Discover")
        try! transitionHandler
            .forStoryboard(factory: factory, to: DiscoverModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(isOpenedFromWelcome: true)
            })
    }
    
    func openDashboard() {
        let factory = StoryboardFactory(storyboardName: "Dashboard")
        try! transitionHandler
            .forStoryboard(factory: factory, to: DashboardModuleInput.self)
            .transition(animate: false)
            .to(preferred: .navigation(style: .push))
            .perform()
    }
}
